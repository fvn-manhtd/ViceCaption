//
//  CaptionPipelineTests.swift
//  VibeCaptionTests
//
//  Integration-style tests for the caption pipeline.
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

    func testPauseStopsProcessing() async throws {
        let harness = try TestHarness()
        let pipeline = harness.pipeline
        defer { pipeline.stop() }

        try await pipeline.start()
        pipeline.pause()
        harness.emitSpeechThenSilence()

        let blocks = await harness.currentBlocks()
        XCTAssertTrue(blocks.isEmpty)
    }

    func testStopSavesTranscript() async throws {
        let harness = try TestHarness()
        let pipeline = harness.pipeline
        defer { pipeline.stop() }

        try await pipeline.start()
        harness.emitSpeechThenSilence()
        _ = try await harness.waitForBlocks(minimum: 1)

        await MainActor.run {
            pipeline.stop()
        }

        let files = try FileManager.default.contentsOfDirectory(atPath: harness.transcriptDirectory.path)
        XCTAssertFalse(files.isEmpty)
    }

    func testErrorPropagation() async throws {
        let errorHarness = try TestHarness(asrError: TestASRError.simulated)
        let pipeline = errorHarness.pipeline
        defer { pipeline.stop() }

        try await pipeline.start()
        errorHarness.emitSpeechThenSilence()

        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if pipeline.currentState == .error {
                break
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTAssertEqual(pipeline.currentState, .error)
        XCTAssertEqual(errorHarness.appStateManager.currentState, .idle)
    }
}

private struct TestHarness {
    let pipeline: CaptionPipeline
    let captureEngine: TestAudioCaptureEngine
    let transcriptManager: TranscriptManager
    let appStateManager: AppStateManager
    let transcriptDirectory: URL

    private let settingsManager: SettingsManager

    init(translationDelay: TimeInterval = 0.05, asrError: Error? = nil) throws {
        let suiteName = "CaptionPipelineTests_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)
        defaults?.removePersistentDomain(forName: suiteName)
        settingsManager = SettingsManager(userDefaults: defaults ?? .standard)

        transcriptDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        settingsManager.transcriptStoragePath = transcriptDirectory.path

        transcriptManager = TranscriptManager(settingsManager: settingsManager)
        appStateManager = AppStateManager()

        captureEngine = TestAudioCaptureEngine()
        let vad = VoiceActivityDetector(speechThreshold: 0.01, silenceThreshold: 0.005)
        let segmenter = AudioSegmenter()
        segmenter.minSegmentDuration = 0.1
        segmenter.maxSegmentDuration = 1.5
        segmenter.silencePadding = 0.05

        let asrService = TestASRService(error: asrError)
        let translationService = TestTranslationService(delay: translationDelay)

        pipeline = CaptionPipeline(
            captureEngine: captureEngine,
            preprocessor: PassThroughPreprocessor(),
            vad: vad,
            segmenter: segmenter,
            asrService: asrService,
            translationService: translationService,
            transcriptManager: transcriptManager,
            appStateManager: appStateManager
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

    func configure(inputDevice: AudioDevice) throws {
        currentInputDevice = inputDevice
    }

    func startCapture() throws {
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
        callback?(buffer)
    }
}

private enum TestASRError: Error {
    case simulated
}

private final class TestASRService: ASRServiceProtocol {
    private(set) var isModelLoaded: Bool = false
    private let error: Error?

    init(error: Error? = nil) {
        self.error = error
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

        let segment = ASRSegment(
            text: "こんにちは",
            startTime: audio.startTime,
            endTime: audio.endTime,
            speakerID: nil,
            confidence: 0.9
        )
        return ASRResult(segments: [segment], processingTime: 0.01)
    }
}

private final class TestTranslationService: TranslationServiceProtocol {
    private(set) var isModelLoaded: Bool = false
    private let delay: TimeInterval

    init(delay: TimeInterval) {
        self.delay = delay
    }

    func loadModel() async throws {
        isModelLoaded = true
    }

    func unloadModel() {
        isModelLoaded = false
    }

    func translate(_ text: String, from sourceLanguage: Language, to targetLanguage: Language) async throws -> TranslationResult {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        return TranslationResult(
            originalText: text,
            translatedText: "Hello",
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
