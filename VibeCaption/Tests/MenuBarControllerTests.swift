//
//  MenuBarControllerTests.swift
//  VibeCaptionTests
//
//  Unit tests for MenuBarController.
//

import XCTest
import AVFoundation
import Combine
@testable import VibeCaption

class MenuBarControllerTests: XCTestCase {
    
    var appStateManager: AppStateManager!
    var settingsManager: SettingsManager!
    var menuBarController: MenuBarController!
    var pipeline: CaptionPipeline!
    
    override func setUp() {
        super.setUp()
        appStateManager = AppStateManager()
        settingsManager = SettingsManager()
        let transcriptManager = TranscriptManager(settingsManager: settingsManager)
        let captureEngine = TestAudioCaptureEngine()
        let asrService = TestASRService()
        let translationService = TestTranslationService()
        pipeline = CaptionPipeline(
            captureEngine: captureEngine,
            preprocessor: PassThroughPreprocessor(),
            vad: VoiceActivityDetector(),
            segmenter: AudioSegmenter(),
            asrService: asrService,
            translationService: translationService,
            transcriptManager: transcriptManager,
            appStateManager: appStateManager
        )
        // MenuBarController initialization creates NSStatusItem, which might not be fully testable 
        // in a headless XCTest environment without UI, but we can test the logic flow 
        // if we decouple it or if the environment allows basic AppKit objects.
        // Assuming partial AppKit availability.
        menuBarController = MenuBarController(
            appStateManager: appStateManager,
            settingsManager: settingsManager,
            pipeline: pipeline
        )
    }
    
    override func tearDown() {
        pipeline?.stop()
        menuBarController = nil
        appStateManager = nil
        settingsManager = nil
        pipeline = nil
        super.tearDown()
    }
    
    // Helper to get menu items
    // Since privacy of properties in controller, we need reflection or exposed properties for testing.
    // For this test, we assume we can check effects on dependencies or rely on notifications.
    // However, purely UI tests are hard. Ideally we'd test the *actions* logic separately.
    // Given the simplified controller, we verify if calling actions updates state.
    
    func testToggleListeningAction() async {
        // Given
        // When: User toggles listening (simulate action)
        // Since we can't easily click the menu item programmatically without reference,
        // we can test the AppStateManager directly or expose the action.
        // But the requirement is to test the wiring.
        // Let's use `perform` on the selector if we can find the menu item.
        
        // Access private statusItem via Mirror to get the menu
        let mirror = Mirror(reflecting: menuBarController!)
        guard let statusItem = mirror.children.first(where: { $0.label == "statusItem" })?.value as? NSStatusItem,
              let menu = statusItem.menu else {
            XCTFail("Could not access status item menu")
            return
        }
        
        guard let startListeningItem = menu.items.first(where: { $0.title == "Start Listening" }) else {
            XCTFail("Start Listening item not found")
            return
        }
        
        // Perform action
        _ = menu.performActionForItem(at: menu.index(of: startListeningItem))
        
        await waitForState(.listening)
        XCTAssertEqual(appStateManager.currentState, .listening)
    }
    
    func testMenuStateUpdates() async {
        let mirror = Mirror(reflecting: menuBarController!)
        guard let statusItem = mirror.children.first(where: { $0.label == "statusItem" })?.value as? NSStatusItem,
              let menu = statusItem.menu else {
            XCTFail("Could not access status item menu")
            return
        }
        
        // Initially Idle -> "Start Listening"
        guard let item = menu.items.first(where: { $0.action == Selector(("toggleListening")) }) else {
            XCTFail("Toggle listening item not found")
            return
        }
        XCTAssertEqual(item.title, "Start Listening")
        
        // Change State -> Listening
        Task { try? await pipeline.start() }
        await waitForState(.listening)
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        XCTAssertEqual(item.title, "Stop Listening")
    }
    
    func testOverlayToggle() {
        let mirror = Mirror(reflecting: menuBarController!)
        guard let statusItem = mirror.children.first(where: { $0.label == "statusItem" })?.value as? NSStatusItem,
              let menu = statusItem.menu else {
            XCTFail("Could not access status item menu")
            return
        }
        
        guard let item = menu.items.first(where: { $0.action == Selector(("toggleOverlay")) }) else {
            XCTFail("Toggle overlay item not found")
            return
        }
        
        // Initially generic/hide depending on default?
        // AppStateManager defaults isOverlayVisible = false
        XCTAssertEqual(item.title, "Show Overlay")
        
        // Toggle
        appStateManager.overlayWillShow()
        
        let expectation = XCTestExpectation(description: "Overlay menu update")
        DispatchQueue.main.async {
            if item.title == "Hide Overlay" {
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(item.title, "Hide Overlay")
    }

    func testOpenTranscriptFolderCreatesDirectory() {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let transcriptDirectory = temporaryRoot.appendingPathComponent("missing/subfolder", isDirectory: true)
        settingsManager.transcriptStoragePath = transcriptDirectory.path

        var openedURL: URL?
        menuBarController = MenuBarController(
            appStateManager: appStateManager,
            settingsManager: settingsManager,
            pipeline: pipeline,
            openURLHandler: { url in
                openedURL = url
                return true
            },
            presentAlert: { _, _ in
                XCTFail("Unexpected alert while opening transcript folder")
            }
        )

        defer {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }

        let mirror = Mirror(reflecting: menuBarController!)
        guard let statusItem = mirror.children.first(where: { $0.label == "statusItem" })?.value as? NSStatusItem,
              let menu = statusItem.menu else {
            XCTFail("Could not access status item menu")
            return
        }

        guard let openItem = menu.items.first(where: { $0.title == "Open Transcript Folder" }) else {
            XCTFail("Open Transcript Folder item not found")
            return
        }

        _ = menu.performActionForItem(at: menu.index(of: openItem))

        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: transcriptDirectory.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
        XCTAssertEqual(openedURL?.path, transcriptDirectory.path)
    }

    private func waitForState(_ state: AppState, timeout: TimeInterval = 1.0) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if appStateManager.currentState == state {
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("Timed out waiting for state \(state)")
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

private final class TestASRService: ASRServiceProtocol {
    private(set) var isModelLoaded: Bool = false

    func loadModel() async throws {
        isModelLoaded = true
    }

    func unloadModel() {
        isModelLoaded = false
    }

    func transcribe(_ audio: AudioSegment) async throws -> ASRResult {
        return ASRResult(segments: [], processingTime: 0)
    }
}

private final class TestTranslationService: TranslationServiceProtocol {
    private(set) var isModelLoaded: Bool = false

    func loadModel() async throws {
        isModelLoaded = true
    }

    func unloadModel() {
        isModelLoaded = false
    }

    func translate(_ text: String, from sourceLanguage: Language, to targetLanguage: Language) async throws -> TranslationResult {
        return TranslationResult(
            originalText: text,
            translatedText: text,
            confidence: 1,
            processingTime: 0,
            targetLanguage: targetLanguage
        )
    }
}

private struct PassThroughPreprocessor: AudioPreprocessorProtocol {
    let outputSampleRate: Double = 16000

    func process(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        buffer
    }

    func reset() {}
}
