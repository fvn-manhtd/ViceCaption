//
//  CaptionPipeline.swift
//  VibeCaption
//
//  Orchestrates the end-to-end audio capture to caption workflow.
//

import AVFoundation
import Combine
import Foundation
import os.log

public enum PipelineState: Equatable {
    case idle
    case listening
    case translating
    case paused
    case error
}

public final class CaptionPipeline: ObservableObject {
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var currentState: PipelineState = .idle
    @Published public private(set) var statistics: PipelineStatistics = PipelineStatistics()
    @Published public private(set) var lastError: Error?
    @Published public private(set) var isPerformanceModeActive: Bool = false
    @Published public private(set) var audioLevel: Float = 0.0

    private let captureEngine: AudioCaptureEngineProtocol
    private let preprocessor: AudioPreprocessorProtocol
    private let vad: VoiceActivityDetector
    private let segmenter: AudioSegmenter
    private let asrService: ASRServiceProtocol
    private let translationService: TranslationServiceProtocol
    private let transcriptManager: TranscriptManager
    private let appStateManager: AppStateManager
    private let settingsManager: SettingsManager?
    private let normalSegmentQueueLimit: Int
    private let performanceSegmentQueueLimit: Int
    private let normalTranslationConcurrencyLimit: Int
    private let performanceTranslationConcurrencyLimit: Int

    private let logger = Logger(subsystem: "com.vibecaption", category: "CaptionPipeline")

    private var segmentContinuation: AsyncStream<AudioSegment>.Continuation?
    private var segmentTask: Task<Void, Never>?
    @MainActor private var translationTasks: [UUID: Task<Void, Never>] = [:]
    @MainActor private var translationTaskOrder: [UUID] = []
    @MainActor private var translationInFlightCount: Int = 0
    private var cancellables = Set<AnyCancellable>()

    private let stateLock = NSLock()
    private var stateSnapshot: PipelineState = .idle

    init(
        captureEngine: AudioCaptureEngineProtocol = AudioCaptureEngine(),
        preprocessor: AudioPreprocessorProtocol = AudioPreprocessor(),
        vad: VoiceActivityDetector = VoiceActivityDetector(),
        segmenter: AudioSegmenter = AudioSegmenter(),
        asrService: ASRServiceProtocol,
        translationService: TranslationServiceProtocol,
        transcriptManager: TranscriptManager,
        appStateManager: AppStateManager,
        settingsManager: SettingsManager? = nil,
        segmentQueueLimit: Int = 8,
        performanceSegmentQueueLimit: Int = 4,
        normalTranslationConcurrencyLimit: Int = 8,
        performanceTranslationConcurrencyLimit: Int = 2
    ) {
        self.captureEngine = captureEngine
        self.preprocessor = preprocessor
        self.vad = vad
        self.segmenter = segmenter
        self.asrService = asrService
        self.translationService = translationService
        self.transcriptManager = transcriptManager
        self.appStateManager = appStateManager
        self.settingsManager = settingsManager
        self.normalSegmentQueueLimit = max(1, segmentQueueLimit)
        self.performanceSegmentQueueLimit = max(1, performanceSegmentQueueLimit)
        self.normalTranslationConcurrencyLimit = max(1, normalTranslationConcurrencyLimit)
        self.performanceTranslationConcurrencyLimit = max(1, performanceTranslationConcurrencyLimit)

        configurePipeline()
        bindCaptureEngine()
    }

    public func start() async throws {
        let snapshot = snapshotState()
        guard snapshot == .idle else {
            if snapshot == .paused {
                resume()
            }
            return
        }

        await resetStatistics()
        await MainActor.run { [weak self] in
            self?.lastError = nil
        }

        do {
            try await loadModelsIfNeeded()
        } catch {
            handlePipelineError(error)
            throw error
        }

        applyRuntimeSettingsToCaptureEngine()
        await syncPerformanceModeFromSettings()

        await MainActor.run { [weak self] in
            self?.transcriptManager.startNewSession()
        }
        startSegmentProcessing()

        do {
            try configureCaptureInputIfNeeded()
            try captureEngine.startCapture()
        } catch {
            handlePipelineError(error)
            throw error
        }

        setState(.listening)
    }

    public func stop(trigger: TranscriptSessionEndTrigger = .manualStop) {
        stopInternal(transitionState: .idle, endTrigger: trigger)
    }

    public func pause() {
        let snapshot = snapshotState()
        guard snapshot == .listening || snapshot == .translating else { return }

        captureEngine.stopCapture()
        stopSegmentProcessing()
        resetAudioProcessors()
        Task { @MainActor [weak self] in
            self?.transcriptManager.addPauseMarker()
            self?.resetTranslationTracking()
        }

        setState(.paused)
    }

    public func resume() {
        let snapshot = snapshotState()
        guard snapshot == .paused else { return }

        applyRuntimeSettingsToCaptureEngine()
        Task { @MainActor [weak self] in
            self?.syncPerformanceModeFromSettings()
        }
        startSegmentProcessing()
        do {
            try configureCaptureInputIfNeeded()
            try captureEngine.startCapture()
        } catch {
            handlePipelineError(error)
            return
        }

        setState(.listening)
    }

    func enqueueSegment(_ segment: AudioSegment) {
        guard snapshotState() == .listening || snapshotState() == .translating else { return }
        guard let continuation = segmentContinuation else { return }

        let result = continuation.yield(segment)
        if case .dropped = result {
            Task { @MainActor [weak self] in
                self?.statistics.recordDroppedSegment()
            }
        }
    }

    // MARK: - Pipeline Setup

    private func configurePipeline() {
        captureEngine.setAudioCallback { [weak self] buffer in
            self?.processAudio(buffer)
        }

        segmenter.setSegmentCallback { [weak self] segment in
            self?.enqueueSegment(segment)
        }
    }

    private func bindCaptureEngine() {
        captureEngine.audioLevelPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.audioLevel = level
            }
            .store(in: &cancellables)
    }

    private func processAudio(_ buffer: AVAudioPCMBuffer) {
        let snapshot = snapshotState()
        guard snapshot == .listening || snapshot == .translating else { return }

        let cleanedBuffer = preprocessor.process(buffer)
        let vadResult = vad.process(cleanedBuffer)
        segmenter.process(cleanedBuffer, vadResult: vadResult)
    }

    private func startSegmentProcessing() {
        guard segmentTask == nil else { return }
        let queueLimit = currentSegmentQueueLimit()

        let stream = AsyncStream<AudioSegment>(bufferingPolicy: .bufferingOldest(queueLimit)) { continuation in
            continuation.onTermination = { [weak self] _ in
                self?.segmentContinuation = nil
            }
            self.segmentContinuation = continuation
        }

        segmentTask = Task { [weak self] in
            guard let self = self else { return }
            for await segment in stream {
                if Task.isCancelled { break }
                await self.processSegment(segment)
            }
        }
    }

    private func stopSegmentProcessing() {
        segmentContinuation?.finish()
        segmentContinuation = nil
        segmentTask?.cancel()
        segmentTask = nil
    }

    private func processSegment(_ segment: AudioSegment) async {
        let snapshot = snapshotState()
        guard snapshot == .listening || snapshot == .translating else { return }

        let startTime = Date()

        do {
            let result = try await asrService.transcribe(segment)
            if Task.isCancelled { return }

            let blocks = convertToTranscriptBlocks(result)
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                blocks.forEach { self.transcriptManager.addBlock($0) }
            }

            await updateStatistics(latency: Date().timeIntervalSince(startTime), blockCount: blocks.count)

            startTranslation(for: blocks)
        } catch {
            handlePipelineError(error)
        }
    }

    private func startTranslation(for blocks: [TranscriptBlock]) {
        guard !blocks.isEmpty else { return }
        let blocksToTranslate = cappedTranslationBlocks(from: blocks)

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.syncPerformanceModeFromSettings()
            for block in blocksToTranslate {
                let blockID = block.id
                self.enforceTranslationTaskLimit()
                let task = self.makeTranslationTask(for: block)
                self.translationTasks[blockID] = task
                self.translationTaskOrder.append(blockID)
            }
        }
    }

    private func makeTranslationTask(for block: TranscriptBlock) -> Task<Void, Never> {
        let blockID = block.id
        return Task { [weak self] in
            guard let self = self else { return }
            if Task.isCancelled { return }
            await self.updateTranslationCount(by: 1)
            defer {
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.translationTasks[blockID] = nil
                    self.translationTaskOrder.removeAll { $0 == blockID }
                    self.updateTranslationCount(by: -1)
                }
            }

            do {
                let translation = try await translationService.translate(
                    block.japaneseText,
                    from: .japanese,
                    to: .english
                )
                if Task.isCancelled { return }

                await MainActor.run { [weak self] in
                    _ = self?.transcriptManager.updateBlock(id: blockID, englishText: translation.translatedText)
                }
            } catch {
                if Task.isCancelled { return }
                logger.error("Translation failed for block \(blockID.uuidString): \(error.localizedDescription)")
            }
        }
    }

    private func convertToTranscriptBlocks(_ asr: ASRResult) -> [TranscriptBlock] {
        asr.segments.map { segment in
            TranscriptBlock(
                speakerLabel: segment.speakerID.map { "Speaker \($0)" },
                japaneseText: segment.text,
                confidence: segment.confidence
            )
        }
    }

    private func stopInternal(transitionState: PipelineState, endTrigger: TranscriptSessionEndTrigger) {
        captureEngine.stopCapture()
        stopSegmentProcessing()
        resetAudioProcessors()

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.resetTranslationTracking()
        }

        _ = transcriptManager.endCurrentSession(trigger: endTrigger)

        setState(transitionState)
    }

    private func resetAudioProcessors() {
        vad.reset()
        segmenter.reset()
        preprocessor.reset()
    }

    private func handlePipelineError(_ error: Error) {
        logger.error("Pipeline error: \(error.localizedDescription)")
        Task { @MainActor [weak self] in
            self?.lastError = error
        }
        stopInternal(transitionState: .error, endTrigger: .pipelineError)
    }

    private func loadModelsIfNeeded() async throws {
        if !asrService.isModelLoaded {
            try await asrService.loadModel()
        }
        if !translationService.isModelLoaded {
            try await translationService.loadModel()
        }

        await MainActor.run { [weak self] in
            self?.appStateManager.areModelsLoaded = true
        }
    }

    private func applyRuntimeSettingsToCaptureEngine() {
        let performanceEnabled = settingsManager?.performanceModeEnabled ?? false
        let noiseSuppressionEnabled = settingsManager?.noiseSuppressionEnabled ?? true
        captureEngine.setNoiseSuppression(noiseSuppressionEnabled && !performanceEnabled)
    }

    private func configureCaptureInputIfNeeded() throws {
        let audioManager = AudioDeviceManager.shared
        let selectedInputUID = settingsManager?.audioInputDeviceID

        let resolveInputDevice = { () -> AudioDevice? in
            audioManager.refreshDevices()
            return selectedInputUID.flatMap { uid in
                audioManager.inputDevices.first { $0.uid == uid }
            } ??
            audioManager.getDefaultInputDevice() ??
            audioManager.inputDevices.first
        }

        let inputDevice: AudioDevice?
        if Thread.isMainThread {
            inputDevice = resolveInputDevice()
        } else {
            inputDevice = DispatchQueue.main.sync(execute: resolveInputDevice)
        }

        guard let inputDevice else {
            logger.warning("No input device available for capture; continuing without explicit configuration")
            return
        }

        let performanceEnabled = settingsManager?.performanceModeEnabled ?? false
        let userNoiseSuppressionEnabled = settingsManager?.noiseSuppressionEnabled ?? true
        let isLikelyVirtualInput = inputDevice.isBlackHole ||
            inputDevice.name.localizedCaseInsensitiveContains("aggregate") ||
            inputDevice.uid.localizedCaseInsensitiveContains("aggregate")
        let shouldEnableNoiseSuppression = userNoiseSuppressionEnabled && !performanceEnabled && !isLikelyVirtualInput
        self.captureEngine.setNoiseSuppression(shouldEnableNoiseSuppression)
        if userNoiseSuppressionEnabled && isLikelyVirtualInput {
            self.logger.info("Voice processing disabled for virtual input device: \(inputDevice.name)")
        }

        try self.captureEngine.configure(inputDevice: inputDevice)
        self.logger.info("Capture input configured: \(self.captureEngine.currentInputDevice?.name ?? inputDevice.name)")

        if let selectedInputUID,
           let actualInput = self.captureEngine.currentInputDevice,
           actualInput.uid != selectedInputUID {
            throw VibeCaptionError.audioRoutingFailed(
                device: inputDevice.name,
                reason: "Could not bind selected input. Engine is using \"\(actualInput.name)\" instead."
            )
        }
    }

    private func cappedTranslationBlocks(from blocks: [TranscriptBlock]) -> [TranscriptBlock] {
        let isPerformanceMode = settingsManager?.performanceModeEnabled ?? false
        guard isPerformanceMode else { return blocks }
        let limit = max(1, performanceTranslationConcurrencyLimit)
        guard blocks.count > limit else { return blocks }
        return Array(blocks.suffix(limit))
    }

    private func currentSegmentQueueLimit() -> Int {
        let performanceEnabled = settingsManager?.performanceModeEnabled ?? false
        return performanceEnabled ? performanceSegmentQueueLimit : normalSegmentQueueLimit
    }

    // MARK: - State + Stats

    private func snapshotState() -> PipelineState {
        stateLock.lock()
        defer { stateLock.unlock() }
        return stateSnapshot
    }

    private func setState(_ state: PipelineState) {
        stateLock.lock()
        stateSnapshot = state
        stateLock.unlock()

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.currentState = state
            self.isRunning = state == .listening || state == .translating
            self.syncAppState(to: state)
        }
    }

    @MainActor
    private func syncAppState(to state: PipelineState) {
        switch state {
        case .idle:
            appStateManager.stopListening()
        case .listening:
            if appStateManager.currentState == .paused {
                try? appStateManager.resume()
            } else if appStateManager.currentState == .translating {
                try? appStateManager.endTranslation()
            } else if appStateManager.currentState != .listening {
                try? appStateManager.startListening()
            }
        case .translating:
            if appStateManager.currentState == .listening {
                try? appStateManager.beginTranslation()
            }
        case .paused:
            if appStateManager.currentState != .paused {
                try? appStateManager.pause()
            }
        case .error:
            appStateManager.stopListening()
        }

        updateOverlayVisibility(for: state)
    }

    @MainActor
    private func updateOverlayVisibility(for state: PipelineState) {
        let shouldShow = state == .listening || state == .translating || state == .paused
        if shouldShow, !appStateManager.isOverlayVisible {
            appStateManager.overlayWillShow()
        } else if !shouldShow, appStateManager.isOverlayVisible {
            appStateManager.overlayWillHide()
        }
    }

    @MainActor
    private func updateStatistics(latency: TimeInterval, blockCount: Int) {
        statistics.recordSegment(latency: latency, blockCount: blockCount)
    }

    @MainActor
    private func resetStatistics() {
        statistics.reset()
    }

    @MainActor
    private func updateTranslationCount(by delta: Int) {
        translationInFlightCount = max(0, translationInFlightCount + delta)

        if currentState == .listening && translationInFlightCount > 0 {
            currentState = .translating
        } else if currentState == .translating && translationInFlightCount == 0 {
            currentState = .listening
        }

        if currentState == .listening || currentState == .translating {
            isRunning = true
            stateLock.lock()
            stateSnapshot = currentState
            stateLock.unlock()
            syncAppState(to: currentState)
        }
    }

    @MainActor
    private func resetTranslationTracking() {
        translationTasks.values.forEach { $0.cancel() }
        translationTasks.removeAll()
        translationTaskOrder.removeAll()
        translationInFlightCount = 0
    }

    @MainActor
    private func syncPerformanceModeFromSettings() {
        isPerformanceModeActive = settingsManager?.performanceModeEnabled ?? false
    }

    @MainActor
    private func currentTranslationTaskLimit() -> Int {
        let performanceEnabled = settingsManager?.performanceModeEnabled ?? false
        return performanceEnabled ? performanceTranslationConcurrencyLimit : normalTranslationConcurrencyLimit
    }

    @MainActor
    private func enforceTranslationTaskLimit() {
        let limit = currentTranslationTaskLimit()
        guard translationTasks.count >= limit else { return }

        while translationTasks.count >= limit, let oldestBlockID = translationTaskOrder.first {
            translationTasks[oldestBlockID]?.cancel()
            translationTasks.removeValue(forKey: oldestBlockID)
            translationTaskOrder.removeFirst()
        }
    }
}
