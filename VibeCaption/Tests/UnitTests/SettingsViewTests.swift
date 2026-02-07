//
//  SettingsViewTests.swift
//  VibeCaptionTests
//
//  Unit tests for the Settings panel views.
//

import XCTest
@testable import VibeCaption

final class SettingsViewTests: XCTestCase {
    
    // MARK: - Properties
    
    var settingsManager: SettingsManager!
    var audioDeviceManager: AudioDeviceManager!
    var modelManager: ModelManager!
    var appStateManager: AppStateManager!
    var updateManager: UpdateManager!
    var transcriptManager: TranscriptManager!
    var pipeline: CaptionPipeline!
    var testUserDefaults: UserDefaults!
    var testSuiteName: String!
    
    // MARK: - Setup / Teardown
    
    override func setUp() {
        super.setUp()
        
        // Create isolated UserDefaults for testing
        testSuiteName = "com.vibecaption.tests.settings.\(UUID().uuidString)"
        testUserDefaults = UserDefaults(suiteName: testSuiteName)!
        
        settingsManager = SettingsManager(userDefaults: testUserDefaults)
        audioDeviceManager = AudioDeviceManager()
        modelManager = ModelManager(settingsManager: settingsManager)
        appStateManager = AppStateManager()
        updateManager = UpdateManager(settingsManager: settingsManager)
        transcriptManager = TranscriptManager(settingsManager: settingsManager)
        pipeline = CaptionPipeline(
            asrService: MockASRService(),
            translationService: MockTranslationService(),
            transcriptManager: transcriptManager,
            appStateManager: appStateManager,
            settingsManager: settingsManager
        )
    }
    
    override func tearDown() {
        testUserDefaults.removePersistentDomain(forName: testSuiteName)
        testUserDefaults = nil
        settingsManager = nil
        audioDeviceManager = nil
        modelManager = nil
        appStateManager = nil
        updateManager = nil
        transcriptManager = nil
        pipeline = nil
        super.tearDown()
    }
    
    // MARK: - Settings Binding Tests
    
    /// Test that performance mode binding works correctly
    func testPerformanceModeBinding() {
        // Initial default
        XCTAssertFalse(settingsManager.performanceModeEnabled)
        
        // Change setting
        settingsManager.performanceModeEnabled = true
        XCTAssertTrue(settingsManager.performanceModeEnabled)
        
        // Verify persistence
        let newManager = SettingsManager(userDefaults: testUserDefaults)
        XCTAssertTrue(newManager.performanceModeEnabled)
    }
    
    /// Test that noise suppression binding works correctly
    func testNoiseSuppressionBinding() {
        // Initial default
        XCTAssertTrue(settingsManager.noiseSuppressionEnabled)
        
        // Change setting
        settingsManager.noiseSuppressionEnabled = false
        XCTAssertFalse(settingsManager.noiseSuppressionEnabled)
        
        // Verify persistence
        let newManager = SettingsManager(userDefaults: testUserDefaults)
        XCTAssertFalse(newManager.noiseSuppressionEnabled)
    }
    
    /// Test that overlay font size binding works correctly
    func testOverlayFontSizeBinding() {
        // Initial default
        XCTAssertEqual(settingsManager.overlayFontSize, .medium)
        
        // Change to each size
        for size in FontSize.allCases {
            settingsManager.overlayFontSize = size
            XCTAssertEqual(settingsManager.overlayFontSize, size)
        }
        
        // Verify persistence
        settingsManager.overlayFontSize = .large
        let newManager = SettingsManager(userDefaults: testUserDefaults)
        XCTAssertEqual(newManager.overlayFontSize, .large)
    }
    
    /// Test that overlay max width binding works correctly
    func testOverlayMaxWidthBinding() {
        // Initial default
        XCTAssertEqual(settingsManager.overlayMaxWidth, 480)
        
        // Change to various widths in range
        let testWidths: [CGFloat] = [320, 400, 600, 800]
        for width in testWidths {
            settingsManager.overlayMaxWidth = width
            XCTAssertEqual(settingsManager.overlayMaxWidth, width)
        }
        
        // Verify persistence
        settingsManager.overlayMaxWidth = 640
        let newManager = SettingsManager(userDefaults: testUserDefaults)
        XCTAssertEqual(newManager.overlayMaxWidth, 640)
    }
    
    /// Test that auto-hide seconds binding works correctly
    func testAutoHideSecondsBinding() {
        // Initial default
        XCTAssertEqual(settingsManager.overlayAutoHideSeconds, 30)
        
        // Test various values
        let testValues = [0, 15, 30, 60]
        for seconds in testValues {
            settingsManager.overlayAutoHideSeconds = seconds
            XCTAssertEqual(settingsManager.overlayAutoHideSeconds, seconds)
        }
        
        // Verify persistence
        settingsManager.overlayAutoHideSeconds = 60
        let newManager = SettingsManager(userDefaults: testUserDefaults)
        XCTAssertEqual(newManager.overlayAutoHideSeconds, 60)
    }
    
    // MARK: - Device Picker Tests
    
    /// Test that audio device ID settings persist correctly
    func testAudioDeviceIDPersistence() {
        // Initial default is nil
        XCTAssertNil(settingsManager.audioInputDeviceID)
        XCTAssertNil(settingsManager.monitoringOutputDeviceID)
        
        // Set device IDs
        let inputID = "test-input-device-uid"
        let outputID = "test-output-device-uid"
        
        settingsManager.audioInputDeviceID = inputID
        settingsManager.monitoringOutputDeviceID = outputID
        
        // Verify persistence
        let newManager = SettingsManager(userDefaults: testUserDefaults)
        XCTAssertEqual(newManager.audioInputDeviceID, inputID)
        XCTAssertEqual(newManager.monitoringOutputDeviceID, outputID)
    }
    
    /// Test that clearing device ID sets to nil
    func testClearingDeviceIDSetsToNil() {
        // Set then clear
        settingsManager.audioInputDeviceID = "some-device"
        settingsManager.audioInputDeviceID = nil
        
        XCTAssertNil(settingsManager.audioInputDeviceID)
        
        // Verify persistence
        let newManager = SettingsManager(userDefaults: testUserDefaults)
        XCTAssertNil(newManager.audioInputDeviceID)
    }
    
    // MARK: - Model List Tests
    
    /// Test that model manager initializes properly
    func testModelManagerInitialization() {
        XCTAssertNotNil(modelManager)
        // Models array should be empty until catalog is loaded
        XCTAssertTrue(modelManager.models.isEmpty)
    }
    
    /// Test model ready status check
    func testModelReadyStatus() {
        // No models loaded, should return false for any ID
        XCTAssertFalse(modelManager.isModelReady("some-model-id"))
    }
    
    /// Test disk usage calculation with no models
    func testDiskUsageWithNoModels() {
        // With no downloaded models, disk usage should be 0
        XCTAssertEqual(modelManager.getTotalDiskUsage(), 0)
    }
    
    // MARK: - Diagnostics Tests
    
    /// Test that diagnostics shows current app state
    func testDiagnosticsShowsAppState() {
        // Initial state should be idle
        XCTAssertEqual(appStateManager.currentState, .idle)
        XCTAssertEqual(appStateManager.currentState.displayName, "Idle")
    }
    
    /// Test that diagnostics reflects state changes
    func testDiagnosticsReflectsStateChanges() {
        // Enable models to allow state transitions
        appStateManager.areModelsLoaded = true
        
        // Start listening
        try? appStateManager.startListening()
        XCTAssertEqual(appStateManager.currentState, .listening)
        XCTAssertEqual(appStateManager.currentState.displayName, "Listening")
        
        // Pause
        try? appStateManager.pause()
        XCTAssertEqual(appStateManager.currentState, .paused)
        XCTAssertEqual(appStateManager.currentState.displayName, "Paused")
        
        // Stop
        appStateManager.stopListening()
        XCTAssertEqual(appStateManager.currentState, .idle)
    }
    
    // MARK: - Settings Window Tests
    
    /// Test that SettingsWindow can be created with dependencies
    func testSettingsWindowCreation() {
        let window = SettingsWindow.create(
            settingsManager: settingsManager,
            audioDeviceManager: audioDeviceManager,
            modelManager: modelManager,
            appStateManager: appStateManager,
            updateManager: updateManager,
            pipeline: pipeline
        )
        
        XCTAssertNotNil(window)
        XCTAssertEqual(window.title, "VibeCaption Settings")
    }
    
    /// Test settings window has correct minimum size
    func testSettingsWindowMinimumSize() {
        let window = SettingsWindow.create(
            settingsManager: settingsManager,
            audioDeviceManager: audioDeviceManager,
            modelManager: modelManager,
            appStateManager: appStateManager,
            updateManager: updateManager,
            pipeline: pipeline
        )
        
        XCTAssertEqual(window.minSize.width, 760)
        XCTAssertEqual(window.minSize.height, 520)
    }
    
    // MARK: - FontSize Tests
    
    /// Test FontSize rawValue roundtrip
    func testFontSizeRawValueRoundtrip() {
        for size in FontSize.allCases {
            let rawValue = size.rawValue
            let restored = FontSize(rawValue: rawValue)
            XCTAssertEqual(restored, size)
        }
    }
    
    /// Test FontSize fontSize property
    func testFontSizeFontSizeProperty() {
        XCTAssertEqual(FontSize.small.fontSize, 12)
        XCTAssertEqual(FontSize.medium.fontSize, 14)
        XCTAssertEqual(FontSize.large.fontSize, 18)
    }
}
