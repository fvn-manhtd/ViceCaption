//
//  SettingsManagerTests.swift
//  VibeCaptionTests
//
//  Comprehensive unit tests for SettingsManager.
//

import XCTest
@testable import VibeCaption

final class SettingsManagerTests: XCTestCase {
    
    var sut: SettingsManager!
    var testUserDefaults: UserDefaults!
    var testSuiteName: String!
    
    override func setUp() {
        super.setUp()
        // Create isolated UserDefaults for each test
        testSuiteName = "com.vibecaption.tests.\(UUID().uuidString)"
        testUserDefaults = UserDefaults(suiteName: testSuiteName)!
        sut = SettingsManager(userDefaults: testUserDefaults)
    }
    
    override func tearDown() {
        // Clean up test UserDefaults
        testUserDefaults.removePersistentDomain(forName: testSuiteName)
        testUserDefaults = nil
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Default Values Tests
    
    /// Test that audioInputDeviceID defaults to nil
    func testAudioInputDeviceIDDefaultsToNil() {
        XCTAssertNil(sut.audioInputDeviceID)
    }
    
    /// Test that monitoringOutputDeviceID defaults to nil
    func testMonitoringOutputDeviceIDDefaultsToNil() {
        XCTAssertNil(sut.monitoringOutputDeviceID)
    }
    
    /// Test that overlayFontSize defaults to medium
    func testOverlayFontSizeDefaultsToMedium() {
        XCTAssertEqual(sut.overlayFontSize, .medium)
    }
    
    /// Test that overlayMaxWidth defaults to 480
    func testOverlayMaxWidthDefaultsTo480() {
        XCTAssertEqual(sut.overlayMaxWidth, 480)
    }
    
    /// Test that overlayAutoHideSeconds defaults to 30
    func testOverlayAutoHideSecondsDefaultsTo30() {
        XCTAssertEqual(sut.overlayAutoHideSeconds, 30)
    }
    
    /// Test that noiseSuppressionEnabled defaults to true
    func testNoiseSuppressionEnabledDefaultsToTrue() {
        XCTAssertTrue(sut.noiseSuppressionEnabled)
    }
    
    /// Test that performanceModeEnabled defaults to false
    func testPerformanceModeEnabledDefaultsToFalse() {
        XCTAssertFalse(sut.performanceModeEnabled)
    }
    
    /// Test that modelStoragePath has expected default
    func testModelStoragePathHasDefault() {
        XCTAssertTrue(sut.modelStoragePath.contains("VibeCaption/Models"))
    }
    
    /// Test that transcriptStoragePath has expected default
    func testTranscriptStoragePathHasDefault() {
        XCTAssertTrue(sut.transcriptStoragePath.contains("VibeCaption/Transcripts"))
    }
    
    // MARK: - Persistence Tests (Read/Write Roundtrip)
    
    /// Test audioInputDeviceID persistence
    func testAudioInputDeviceIDPersistence() {
        sut.audioInputDeviceID = "test-input-device"
        
        // Create new manager with same UserDefaults to simulate restart
        let newManager = SettingsManager(userDefaults: testUserDefaults)
        XCTAssertEqual(newManager.audioInputDeviceID, "test-input-device")
    }
    
    /// Test monitoringOutputDeviceID persistence
    func testMonitoringOutputDeviceIDPersistence() {
        sut.monitoringOutputDeviceID = "test-output-device"
        
        let newManager = SettingsManager(userDefaults: testUserDefaults)
        XCTAssertEqual(newManager.monitoringOutputDeviceID, "test-output-device")
    }
    
    /// Test overlayFontSize persistence
    func testOverlayFontSizePersistence() {
        sut.overlayFontSize = .large
        
        let newManager = SettingsManager(userDefaults: testUserDefaults)
        XCTAssertEqual(newManager.overlayFontSize, .large)
    }
    
    /// Test overlayMaxWidth persistence
    func testOverlayMaxWidthPersistence() {
        sut.overlayMaxWidth = 600
        
        let newManager = SettingsManager(userDefaults: testUserDefaults)
        XCTAssertEqual(newManager.overlayMaxWidth, 600)
    }
    
    /// Test overlayAutoHideSeconds persistence
    func testOverlayAutoHideSecondsPersistence() {
        sut.overlayAutoHideSeconds = 60
        
        let newManager = SettingsManager(userDefaults: testUserDefaults)
        XCTAssertEqual(newManager.overlayAutoHideSeconds, 60)
    }
    
    /// Test noiseSuppressionEnabled persistence
    func testNoiseSuppressionEnabledPersistence() {
        sut.noiseSuppressionEnabled = false
        
        let newManager = SettingsManager(userDefaults: testUserDefaults)
        XCTAssertFalse(newManager.noiseSuppressionEnabled)
    }
    
    /// Test performanceModeEnabled persistence
    func testPerformanceModeEnabledPersistence() {
        sut.performanceModeEnabled = true
        
        let newManager = SettingsManager(userDefaults: testUserDefaults)
        XCTAssertTrue(newManager.performanceModeEnabled)
    }
    
    /// Test modelStoragePath persistence
    func testModelStoragePathPersistence() {
        let customPath = "/tmp/test/models"
        sut.modelStoragePath = customPath
        
        let newManager = SettingsManager(userDefaults: testUserDefaults)
        XCTAssertEqual(newManager.modelStoragePath, customPath)
    }
    
    /// Test transcriptStoragePath persistence
    func testTranscriptStoragePathPersistence() {
        let customPath = "/tmp/test/transcripts"
        sut.transcriptStoragePath = customPath
        
        let newManager = SettingsManager(userDefaults: testUserDefaults)
        XCTAssertEqual(newManager.transcriptStoragePath, customPath)
    }
    
    // MARK: - Path Validation Tests
    
    /// Test that validatePath creates directory if not exists
    func testValidatePathCreatesDirectory() {
        let testPath = NSTemporaryDirectory() + "vibecaption-test-\(UUID().uuidString)"
        
        // Ensure path doesn't exist
        XCTAssertFalse(FileManager.default.fileExists(atPath: testPath))
        
        // Validate should create it
        let result = sut.validatePath(testPath)
        
        XCTAssertTrue(result)
        XCTAssertTrue(FileManager.default.fileExists(atPath: testPath))
        
        // Cleanup
        try? FileManager.default.removeItem(atPath: testPath)
    }
    
    /// Test that validatePath returns true for existing directory
    func testValidatePathReturnsTrueForExistingDirectory() {
        let testPath = NSTemporaryDirectory()
        
        let result = sut.validatePath(testPath)
        
        XCTAssertTrue(result)
    }
    
    /// Test that validatePath handles nested directories
    func testValidatePathCreatesNestedDirectories() {
        let testPath = NSTemporaryDirectory() + "vibecaption-test-\(UUID().uuidString)/nested/deep"
        
        let result = sut.validatePath(testPath)
        
        XCTAssertTrue(result)
        XCTAssertTrue(FileManager.default.fileExists(atPath: testPath))
        
        // Cleanup - remove parent
        let parent = NSTemporaryDirectory() + "vibecaption-test-\(testPath.components(separatedBy: "/vibecaption-test-").last?.components(separatedBy: "/").first ?? "")"
        try? FileManager.default.removeItem(atPath: (testPath as NSString).deletingLastPathComponent.deletingLastPathComponent)
    }
    
    // MARK: - Reset to Defaults Tests
    
    /// Test resetToDefaults restores all default values
    func testResetToDefaultsRestoresAllDefaults() {
        // Set custom values first
        sut.audioInputDeviceID = "custom-device"
        sut.monitoringOutputDeviceID = "custom-output"
        sut.overlayFontSize = .small
        sut.overlayMaxWidth = 800
        sut.overlayAutoHideSeconds = 120
        sut.noiseSuppressionEnabled = false
        sut.performanceModeEnabled = true
        sut.modelStoragePath = "/custom/models"
        sut.transcriptStoragePath = "/custom/transcripts"
        
        // Reset
        sut.resetToDefaults()
        
        // Verify all are back to defaults
        XCTAssertNil(sut.audioInputDeviceID)
        XCTAssertNil(sut.monitoringOutputDeviceID)
        XCTAssertEqual(sut.overlayFontSize, .medium)
        XCTAssertEqual(sut.overlayMaxWidth, 480)
        XCTAssertEqual(sut.overlayAutoHideSeconds, 30)
        XCTAssertTrue(sut.noiseSuppressionEnabled)
        XCTAssertFalse(sut.performanceModeEnabled)
        XCTAssertTrue(sut.modelStoragePath.contains("VibeCaption/Models"))
        XCTAssertTrue(sut.transcriptStoragePath.contains("VibeCaption/Transcripts"))
    }
    
    /// Test that reset persists the defaults
    func testResetToDefaultsPersists() {
        sut.overlayFontSize = .large
        sut.resetToDefaults()
        
        let newManager = SettingsManager(userDefaults: testUserDefaults)
        XCTAssertEqual(newManager.overlayFontSize, .medium)
    }
    
    // MARK: - Independent Settings Tests
    
    /// Test that changing one setting doesn't affect others
    func testSettingsAreIndependent() {
        // Set one value
        sut.overlayFontSize = .large
        
        // Verify others unchanged
        XCTAssertNil(sut.audioInputDeviceID)
        XCTAssertEqual(sut.overlayMaxWidth, 480)
        XCTAssertEqual(sut.overlayAutoHideSeconds, 30)
        XCTAssertTrue(sut.noiseSuppressionEnabled)
    }
    
    /// Test multiple settings can be set independently
    func testMultipleSettingsIndependent() {
        sut.overlayFontSize = .small
        sut.overlayMaxWidth = 320
        sut.noiseSuppressionEnabled = false
        
        XCTAssertEqual(sut.overlayFontSize, .small)
        XCTAssertEqual(sut.overlayMaxWidth, 320)
        XCTAssertFalse(sut.noiseSuppressionEnabled)
        // Others still default
        XCTAssertEqual(sut.overlayAutoHideSeconds, 30)
        XCTAssertFalse(sut.performanceModeEnabled)
    }
    
    // MARK: - Current Settings Tests
    
    /// Test currentSettings returns all values correctly
    func testCurrentSettingsReturnsAllValues() {
        sut.audioInputDeviceID = "input-1"
        sut.overlayFontSize = .large
        sut.overlayMaxWidth = 600
        
        let settings = sut.currentSettings
        
        XCTAssertEqual(settings.audioInputDeviceID, "input-1")
        XCTAssertEqual(settings.overlayFontSize, .large)
        XCTAssertEqual(settings.overlayMaxWidth, 600)
        // Defaults for unset values
        XCTAssertEqual(settings.overlayAutoHideSeconds, 30)
        XCTAssertTrue(settings.noiseSuppressionEnabled)
    }
    
    // MARK: - FontSize Enum Tests
    
    /// Test FontSize display names are correct
    func testFontSizeDisplayNames() {
        XCTAssertEqual(FontSize.small.displayName, "Small")
        XCTAssertEqual(FontSize.medium.displayName, "Medium")
        XCTAssertEqual(FontSize.large.displayName, "Large")
    }
    
    /// Test FontSize font sizes are correct
    func testFontSizeValues() {
        XCTAssertEqual(FontSize.small.fontSize, 12)
        XCTAssertEqual(FontSize.medium.fontSize, 14)
        XCTAssertEqual(FontSize.large.fontSize, 18)
    }
    
    /// Test FontSize is CaseIterable
    func testFontSizeAllCases() {
        XCTAssertEqual(FontSize.allCases.count, 3)
        XCTAssertTrue(FontSize.allCases.contains(.small))
        XCTAssertTrue(FontSize.allCases.contains(.medium))
        XCTAssertTrue(FontSize.allCases.contains(.large))
    }
    
    // MARK: - AppSettings Model Tests
    
    /// Test AppSettings default initializer
    func testAppSettingsDefaultInit() {
        let settings = AppSettings()
        
        XCTAssertNil(settings.audioInputDeviceID)
        XCTAssertNil(settings.monitoringOutputDeviceID)
        XCTAssertEqual(settings.overlayFontSize, .medium)
        XCTAssertEqual(settings.overlayMaxWidth, 480)
        XCTAssertEqual(settings.overlayAutoHideSeconds, 30)
        XCTAssertTrue(settings.noiseSuppressionEnabled)
        XCTAssertFalse(settings.performanceModeEnabled)
    }
    
    /// Test AppSettings custom initializer
    func testAppSettingsCustomInit() {
        let settings = AppSettings(
            audioInputDeviceID: "custom-input",
            overlayFontSize: .large,
            overlayMaxWidth: 800
        )
        
        XCTAssertEqual(settings.audioInputDeviceID, "custom-input")
        XCTAssertEqual(settings.overlayFontSize, .large)
        XCTAssertEqual(settings.overlayMaxWidth, 800)
        // Others should be defaults
        XCTAssertEqual(settings.overlayAutoHideSeconds, 30)
    }
    
    /// Test AppSettings equatable
    func testAppSettingsEquatable() {
        let settings1 = AppSettings()
        let settings2 = AppSettings()
        
        XCTAssertEqual(settings1, settings2)
        
        var settings3 = AppSettings()
        settings3.overlayFontSize = .large
        
        XCTAssertNotEqual(settings1, settings3)
    }
}
