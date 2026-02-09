//
//  CaptionPipelineTests.swift
//  VibeCaptionTests
//
//  Integration-style tests for the caption pipeline and edge-case behavior.
//

import XCTest
import AVFoundation
import Combine
@testable import VibeCaption

final class CaptionPipelineTests: XCTestCase {
    func testPipelineProcessesSegmentWithMocks() async throws {
        let harness = try TestHarness()
        let pipeline = harness.pipeline
        defer { pipeline.stop() }

        try await pipeline.start()
        harness.emitSpeechThenSilence()

        let blocks = try await harness.waitForBlocks(minimum: 1)
        XCTAssertEqual(blocks.first?.japaneseText, "こんにちは")

        let translated = try await harness.waitForTranslation(blockID: blocks[0].id)
        XCTAssertEqual(translated.englishText, "Hello")
    }

    func testJapaneseAppearsBeforeEnglish() async throws {
        let harness = try TestHarness(translationDelay: 0.25)
        let pipeline = harness.pipeline
        defer { pipeline.stop() }

        try await pipeline.start()
        harness.emitSpeechThenSilence()

        let blocks = try await harness.waitForBlocks(minimum: 1)
        XCTAssertNil(blocks.first?.englishText)

        let translated = try await harness.waitForTranslation(blockID: blocks[0].id)
        XCTAssertEqual(translated.englishText, "Hello")
    }

    func testEndToEndMeetingFlowSavesTranscriptWithExpectedOrderAndFields() async throws {
        let segments = [
            ASRSegment(text: "皆さん、今日の議題を確認します。", startTime: 0, endTime: 1, speakerID: 1, confidence: 0.95),
            ASRSegment(text: "了解しました。進めてください。", startTime: 1, endTime: 2, speakerID: 2, confidence: 0.93)
        ]
        let translations = [
            "皆さん、今日の議題を確認します。": "Let's review today's agenda.",
            "了解しました。進めてください。": "Understood. Please continue."
        ]

        let harness = try TestHarness(
            translationDelay: 0.15,
            asrSegments: segments,
            translationMap: translations
        )
        defer { harness.pipeline.stop() }

        try await harness.pipeline.start()
        harness.emitSpeechThenSilence()

        let blocks = try await harness.waitForBlocks(minimum: 2)
        XCTAssertEqual(blocks.first?.speakerLabel, "Speaker 1")
        XCTAssertEqual(blocks.last?.speakerLabel, "Speaker 2")
        XCTAssertNil(blocks.first?.englishText, "Japanese should be available before translation finishes")

        let translatedBlocks = try await harness.waitForTranslatedBlocks(minimum: 2)
        XCTAssertEqual(translatedBlocks.first?.englishText, "Let's review today's agenda.")
        XCTAssertEqual(translatedBlocks.last?.englishText, "Understood. Please continue.")

        let transcript = try await harness.stopAndLoadTranscriptFile()
        XCTAssertTrue(transcript.contains("(Speaker 1)"))
        XCTAssertTrue(transcript.contains("(Speaker 2)"))
        XCTAssertTrue(transcript.contains("皆さん、今日の議題を確認します。"))
        XCTAssertTrue(transcript.contains("Let's review today's agenda."))
        XCTAssertTrue(transcript.contains("了解しました。進めてください。"))
        XCTAssertTrue(transcript.contains("Understood. Please continue."))
        XCTAssertTrue(transcript.range(of: #"\[\d{2}:\d{2}:\d{2}\]"#, options: .regularExpression) != nil)

        let japaneseRange = try XCTUnwrap(transcript.range(of: "皆さん、今日の議題を確認します。"))
        let englishRange = try XCTUnwrap(transcript.range(of: "Let's review today's agenda."))
        XCTAssertLessThan(japaneseRange.lowerBound, englishRange.lowerBound)
    }

    func testNoisyAudioStillProducesCaptions() async throws {
        let harness = try TestHarness()
        defer { harness.pipeline.stop() }

        try await harness.pipeline.start()
        harness.emitNoisySpeechThenSilence()

        let blocks = try await harness.waitForBlocks(minimum: 1, timeout: 3.0)
        XCTAssertFalse(blocks.isEmpty)
    }

    func testTranslationModelUnloadMidTranscriptionKeepsJapaneseText() async throws {
        let harness = try TestHarness(
            translationRequiresLoadedModel: true,
            unloadTranslationModelBeforeFirstTranslate: true
        )
        defer { harness.pipeline.stop() }

        try await harness.pipeline.start()
        harness.emitSpeechThenSilence()

        let blocks = try await harness.waitForBlocks(minimum: 1)
        XCTAssertEqual(blocks.first?.japaneseText, "こんにちは")

        try await Task.sleep(nanoseconds: 400_000_000)
        let updatedBlocks = await harness.currentBlocks()
        XCTAssertNil(updatedBlocks.first?.englishText)
        XCTAssertNotEqual(harness.pipeline.currentState, .error)
    }

    func testPerformanceModeLimitsTranslationConcurrency() async throws {
        let segments = [
            ASRSegment(text: "一", startTime: 0, endTime: 1, speakerID: 1, confidence: 0.95),
            ASRSegment(text: "二", startTime: 1, endTime: 2, speakerID: 2, confidence: 0.95),
            ASRSegment(text: "三", startTime: 2, endTime: 3, speakerID: 3, confidence: 0.95),
            ASRSegment(text: "四", startTime: 3, endTime: 4, speakerID: 4, confidence: 0.95)
        ]

        let harness = try TestHarness(
            translationDelay: 0.4,
            asrSegments: segments,
            performanceModeEnabled: true
        )
        defer { harness.pipeline.stop() }

        try await harness.pipeline.start()
        harness.emitSpeechThenSilence()
        _ = try await harness.waitForBlocks(minimum: 4, timeout: 3.0)
        try await harness.waitForTranslationRequests(minimum: 1, timeout: 3.0)

        XCTAssertTrue(harness.pipeline.isPerformanceModeActive)
        XCTAssertLessThanOrEqual(harness.translationService.maxConcurrentRequests, 2)
    }

    func testCaptureStartFailureTransitionsPipelineToError() async throws {
        let harness = try TestHarness(captureStartError: TestCaptureError.deviceDisconnected)

        do {
            try await harness.pipeline.start()
            XCTFail("Expected capture start to fail")
        } catch {
            // expected
        }

        let deadline = Date().addingTimeInterval(1.0)
        while Date() < deadline, harness.pipeline.currentState != .error {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(harness.pipeline.currentState, .error)
        XCTAssertEqual(harness.appStateManager.currentState, .idle)
    }

    func testPipelineRetryAfterErrorAttemptsStartAgain() async throws {
        let harness = try TestHarness(captureStartError: TestCaptureError.deviceDisconnected)

        do {
            try await harness.pipeline.start()
            XCTFail("Expected initial capture start to fail")
        } catch {
            // expected
        }

        var deadline = Date().addingTimeInterval(1.0)
        while Date() < deadline, harness.pipeline.currentState != .error {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(harness.pipeline.currentState, .error)

        do {
            try await harness.pipeline.start()
            XCTFail("Expected retry to attempt capture start and fail")
        } catch {
            // expected
        }

        deadline = Date().addingTimeInterval(1.0)
        while Date() < deadline, harness.pipeline.currentState != .error {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(harness.pipeline.currentState, .error)
        XCTAssertEqual(harness.appStateManager.currentState, .idle)
    }

    func testPipelinePublishesAudioLevelFromCaptureEngine() async throws {
        let harness = try TestHarness()
        defer { harness.pipeline.stop() }

        XCTAssertEqual(harness.pipeline.audioLevel, 0, accuracy: 0.0001)

        harness.emitAudioLevel(amplitude: 0.3)

        let deadline = Date().addingTimeInterval(1.0)
        while Date() < deadline, harness.pipeline.audioLevel <= 0 {
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertGreaterThan(harness.pipeline.audioLevel, 0)
    }
}

private struct TestHarness {
    let pipeline: CaptionPipeline
    let captureEngine: TestAudioCaptureEngine
    let transcriptManager: TranscriptManager
    let appStateManager: AppStateManager
    let translationService: TestTranslationService
    let transcriptDirectory: URL

    private let settingsManager: SettingsManager

    init(
        translationDelay: TimeInterval = 0.05,
        asrError: Error? = nil,
        asrSegments: [ASRSegment]? = nil,
        translationMap: [String: String] = [:],
        translationRequiresLoadedModel: Bool = false,
        unloadTranslationModelBeforeFirstTranslate: Bool = false,
        performanceModeEnabled: Bool = false,
        captureStartError: Error? = nil
    ) throws {
        let suiteName = "CaptionPipelineTests_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)
        defaults?.removePersistentDomain(forName: suiteName)
        settingsManager = SettingsManager(userDefaults: defaults ?? .standard)
        settingsManager.performanceModeEnabled = performanceModeEnabled

        transcriptDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        settingsManager.transcriptStoragePath = transcriptDirectory.path

        transcriptManager = TranscriptManager(settingsManager: settingsManager)
        appStateManager = AppStateManager()

        captureEngine = TestAudioCaptureEngine(startError: captureStartError)
        let vad = VoiceActivityDetector(speechThreshold: 0.01, silenceThreshold: 0.005)
        let segmenter = AudioSegmenter()
        segmenter.minSegmentDuration = 0.1
        segmenter.maxSegmentDuration = 1.5
        segmenter.silencePadding = 0.05

        let resolvedSegments = asrSegments ?? [
            ASRSegment(text: "こんにちは", startTime: 0, endTime: 1, speakerID: nil, confidence: 0.9)
        ]
        let asrService = TestASRService(error: asrError, segments: resolvedSegments)
        translationService = TestTranslationService(
            delay: translationDelay,
            translations: translationMap,
            requiresLoadedModel: translationRequiresLoadedModel,
            unloadBeforeFirstTranslate: unloadTranslationModelBeforeFirstTranslate
        )

        pipeline = CaptionPipeline(
            captureEngine: captureEngine,
            preprocessor: PassThroughPreprocessor(),
            vad: vad,
            segmenter: segmenter,
            asrService: asrService,
            translationService: translationService,
            transcriptManager: transcriptManager,
            appStateManager: appStateManager,
            settingsManager: settingsManager
        )
    }

    func emitSpeechThenSilence() {
        let speechBuffer = makeBuffer(amplitude: 0.1, frames: 1600)
        let silenceBuffer = makeBuffer(amplitude: 0.0, frames: 1600)

        for _ in 0..<3 {
            captureEngine.emit(speechBuffer)
        }
        for _ in 0..<10 {
            captureEngine.emit(silenceBuffer)
        }
    }

    func emitNoisySpeechThenSilence() {
        let silenceBuffer = makeBuffer(amplitude: 0.0, frames: 1600)

        for index in 0..<8 {
            let noise = Float.random(in: 0.02...0.06)
            let burst = Float.random(in: 0.07...0.13)
            let amplitude = index.isMultiple(of: 2) ? burst : noise
            captureEngine.emit(makeBuffer(amplitude: amplitude, frames: 1600))
        }
        for _ in 0..<12 {
            captureEngine.emit(silenceBuffer)
        }
    }

    func emitAudioLevel(amplitude: Float) {
        captureEngine.emit(makeBuffer(amplitude: amplitude, frames: 1600))
    }

    func currentBlocks() async -> [TranscriptBlock] {
        await MainActor.run {
            transcriptManager.displayableBlocks
        }
    }

    func waitForBlocks(minimum: Int, timeout: TimeInterval = 2.0) async throws -> [TranscriptBlock] {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let blocks = await currentBlocks()
            if blocks.count >= minimum {
                return blocks
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw TestHarnessError.timeout("Timed out waiting for transcript blocks")
    }

    func waitForTranslation(blockID: UUID, timeout: TimeInterval = 2.0) async throws -> TranscriptBlock {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let blocks = await currentBlocks()
            if let block = blocks.first(where: { $0.id == blockID }), block.englishText != nil {
                return block
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw TestHarnessError.timeout("Timed out waiting for translation")
    }

    func waitForTranslatedBlocks(minimum: Int, timeout: TimeInterval = 3.0) async throws -> [TranscriptBlock] {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let blocks = await currentBlocks()
            let translatedCount = blocks.filter { $0.englishText?.isEmpty == false }.count
            if translatedCount >= minimum {
                return blocks
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw TestHarnessError.timeout("Timed out waiting for translated blocks")
    }

    func waitForTranslationRequests(minimum: Int, timeout: TimeInterval = 2.0) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if translationService.maxConcurrentRequests >= minimum {
                return
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        throw TestHarnessError.timeout("Timed out waiting for translation requests")
    }

    func stopAndLoadTranscriptFile() async throws -> String {
        await MainActor.run {
            pipeline.stop(trigger: .manualStop)
        }

        let files = try FileManager.default.contentsOfDirectory(
            at: transcriptDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ).filter { $0.pathExtension == "txt" }

        guard let fileURL = files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).last else {
            throw TestHarnessError.timeout("Expected saved transcript file")
        }

        return try String(contentsOf: fileURL, encoding: .utf8)
    }

    private func makeBuffer(amplitude: Float, frames: AVAudioFrameCount) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames

        let channel = buffer.floatChannelData![0]
        for index in 0..<Int(frames) {
            channel[index] = amplitude
        }
        return buffer
    }
}

private final class TestAudioCaptureEngine: AudioCaptureEngineProtocol {
    @Published private(set) var audioLevel: Float = 0
    var audioLevelPublisher: Published<Float>.Publisher { $audioLevel }
    private(set) var isCapturing: Bool = false
    private(set) var currentInputDevice: AudioDevice?
    private(set) var monitoringEnabled: Bool = false
    private(set) var monitoringVolume: Float = 1
    private(set) var currentMonitoringDevice: AudioDevice?
    private var callback: ((AVAudioPCMBuffer) -> Void)?
    private let startError: Error?

    init(startError: Error? = nil) {
        self.startError = startError
    }

    func configure(inputDevice: AudioDevice) throws {
        currentInputDevice = inputDevice
    }

    func startCapture() throws {
        if let startError {
            throw startError
        }
        isCapturing = true
    }

    func stopCapture() {
        isCapturing = false
    }

    func setAudioCallback(_ callback: @escaping (AVAudioPCMBuffer) -> Void) {
        self.callback = callback
    }

    func setMonitoringOutput(device: AudioDevice?) throws {
        currentMonitoringDevice = device
    }

    func enableMonitoring(_ enabled: Bool) throws {
        monitoringEnabled = enabled
    }

    func setMonitoringVolume(_ volume: Float) {
        monitoringVolume = volume
    }

    func setNoiseSuppression(_ enabled: Bool) {
        return
    }

    func emit(_ buffer: AVAudioPCMBuffer) {
        audioLevel = computeLevel(from: buffer)
        callback?(buffer)
    }

    private func computeLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else {
            return 0
        }

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        var sumOfSquares: Float = 0
        for channel in 0..<channelCount {
            let samples = channelData[channel]
            for index in 0..<frameLength {
                let sample = samples[index]
                sumOfSquares += sample * sample
            }
        }

        let totalSamples = Float(frameLength * channelCount)
        let rms = sqrt(sumOfSquares / totalSamples)
        return min(rms * 2.0, 1.0)
    }
}

private enum TestCaptureError: Error {
    case deviceDisconnected
}

private final class TestASRService: ASRServiceProtocol {
    private(set) var isModelLoaded: Bool = false
    private let error: Error?
    private let segments: [ASRSegment]

    init(error: Error? = nil, segments: [ASRSegment]) {
        self.error = error
        self.segments = segments
    }

    func loadModel() async throws {
        isModelLoaded = true
    }

    func unloadModel() {
        isModelLoaded = false
    }

    func transcribe(_ audio: AudioSegment) async throws -> ASRResult {
        if let error {
            throw error
        }

        let safeCount = max(1, segments.count)
        let segmentDuration = max(0.01, audio.duration / Double(safeCount))
        let mappedSegments = segments.enumerated().map { index, template in
            let start = audio.startTime + (Double(index) * segmentDuration)
            let end = start + segmentDuration
            return ASRSegment(
                text: template.text,
                startTime: start,
                endTime: end,
                speakerID: template.speakerID,
                confidence: template.confidence
            )
        }
        return ASRResult(segments: mappedSegments, processingTime: 0.01)
    }
}

private enum TestTranslationError: Error {
    case modelNotLoaded
}

private final class TestTranslationService: TranslationServiceProtocol {
    private(set) var isModelLoaded: Bool = false
    private(set) var maxConcurrentRequests: Int = 0
    private let delay: TimeInterval
    private let translations: [String: String]
    private let requiresLoadedModel: Bool
    private let lock = NSLock()
    private var activeRequests: Int = 0
    private var unloadBeforeFirstTranslate: Bool

    init(
        delay: TimeInterval,
        translations: [String: String] = [:],
        requiresLoadedModel: Bool = false,
        unloadBeforeFirstTranslate: Bool = false
    ) {
        self.delay = delay
        self.translations = translations
        self.requiresLoadedModel = requiresLoadedModel
        self.unloadBeforeFirstTranslate = unloadBeforeFirstTranslate
    }

    func loadModel() async throws {
        lock.lock()
        isModelLoaded = true
        lock.unlock()
    }

    func unloadModel() {
        lock.lock()
        isModelLoaded = false
        lock.unlock()
    }

    func translate(_ text: String, from sourceLanguage: Language, to targetLanguage: Language) async throws -> TranslationResult {
        lock.lock()
        if unloadBeforeFirstTranslate {
            unloadBeforeFirstTranslate = false
            isModelLoaded = false
        }
        let loaded = isModelLoaded
        lock.unlock()

        if requiresLoadedModel && !loaded {
            throw TestTranslationError.modelNotLoaded
        }

        lock.lock()
        activeRequests += 1
        maxConcurrentRequests = max(maxConcurrentRequests, activeRequests)
        lock.unlock()

        defer {
            lock.lock()
            activeRequests -= 1
            lock.unlock()
        }

        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        let translatedText = translations[text] ?? (text == "こんにちは" ? "Hello" : "EN: \(text)")
        return TranslationResult(
            originalText: text,
            translatedText: translatedText,
            confidence: 0.95,
            processingTime: delay,
            targetLanguage: targetLanguage
        )
    }
}

private struct PassThroughPreprocessor: AudioPreprocessorProtocol {
    let outputSampleRate: Double = 16_000

    func process(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        buffer
    }

    func reset() {}
}

private enum TestHarnessError: Error {
    case timeout(String)
}
