//
//  CaptionPipeline.swift
//  VibeCaption
//
//  Orchestrates the end-to-end audio capture to caption workflow.
//

import AVFoundation
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

    private let captureEngine: AudioCaptureEngineProtocol
    private let preprocessor: AudioPreprocessorProtocol
    private let vad: VoiceActivityDetector
    private let segmenter: AudioSegmenter
    private let asrService: ASRServiceProtocol
    private let translationService: TranslationServiceProtocol
    private let transcriptManager: TranscriptManager
    private let appStateManager: AppStateManager
    private let segmentQueueLimit: Int

    private let logger = Logger(subsystem: "com.vibecaption", category: "CaptionPipeline")

    private var segmentContinuation: AsyncStream<AudioSegment>.Continuation?
    private var segmentTask: Task<Void, Never>?
    @MainActor private var translationTasks: [UUID: Task<Void, Never>] = [:]
    @MainActor private var translationInFlightCount: Int = 0

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
        segmentQueueLimit: Int = 8
    ) {
        self.captureEngine = captureEngine
        self.preprocessor = preprocessor
        self.vad = vad
        self.segmenter = segmenter
        self.asrService = asrService
        self.translationService = translationService
        self.transcriptManager = transcriptManager
        self.appStateManager = appStateManager
        self.segmentQueueLimit = segmentQueueLimit

        configurePipeline()
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

        await MainActor.run { [weak self] in
            self?.transcriptManager.startNewSession()
        }
        startSegmentProcessing()

        do {
            try captureEngine.startCapture()
        } catch {
            handlePipelineError(error)
            throw error
        }

        setState(.listening)
    }

    public func stop() {
        stopInternal(transitionState: .idle)
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

        startSegmentProcessing()
        do {
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

    private func processAudio(_ buffer: AVAudioPCMBuffer) {
        let snapshot = snapshotState()
        guard snapshot == .listening || snapshot == .translating else { return }

        let cleanedBuffer = preprocessor.process(buffer)
        let vadResult = vad.process(cleanedBuffer)
        segmenter.process(cleanedBuffer, vadResult: vadResult)
    }

    private func startSegmentProcessing() {
        guard segmentTask == nil else { return }

        let stream = AsyncStream<AudioSegment>(bufferingPolicy: .bufferingOldest(segmentQueueLimit)) { continuation in
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

        for block in blocks {
            let blockID = block.id
            let task = Task { [weak self] in
                guard let self = self else { return }
                await self.updateTranslationCount(by: 1)
                defer {
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        self.translationTasks[blockID] = nil
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

            Task { @MainActor [weak self] in
                self?.translationTasks[blockID] = task
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

    private func stopInternal(transitionState: PipelineState) {
        captureEngine.stopCapture()
        stopSegmentProcessing()
        resetAudioProcessors()

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.resetTranslationTracking()
        }

        transcriptManager.endCurrentSession()
        do {
            try transcriptManager.saveSession()
        } catch {
            logger.error("Failed to save transcript: \(error.localizedDescription)")
        }

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
        stopInternal(transitionState: .error)
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
        translationInFlightCount = 0
    }
}
