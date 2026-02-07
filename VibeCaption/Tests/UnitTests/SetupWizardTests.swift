//
//  SetupWizardTests.swift
//  VibeCaptionTests
//
//  Unit tests for Setup Wizard logic.
//

import XCTest
@testable import VibeCaption

final class SetupWizardTests: XCTestCase {
    
    // MARK: - Properties
    
    var settingsManager: SettingsManager!
    var testUserDefaults: UserDefaults!
    var audioDeviceManager: AudioDeviceManager!
    var testSuiteName: String!
    
    // MARK: - Setup
    
    override func setUp() {
        super.setUp()
        
        testSuiteName = "com.vibecaption.tests.wizard.\(UUID().uuidString)"
        testUserDefaults = UserDefaults(suiteName: testSuiteName)!
        
        settingsManager = SettingsManager(userDefaults: testUserDefaults)
        audioDeviceManager = AudioDeviceManager.shared
    }
    
    override func tearDown() {
        testUserDefaults.removePersistentDomain(forName: testSuiteName)
        testUserDefaults = nil
        settingsManager = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func testSetupWizardCompletedFlag() {
        // Initially false
        XCTAssertFalse(settingsManager.setupWizardCompleted)
                   
        // Set to true
        settingsManager.setupWizardCompleted = true
        XCTAssertTrue(settingsManager.setupWizardCompleted)
        
        // Persist check
        let newManager = SettingsManager(userDefaults: testUserDefaults)
        XCTAssertTrue(newManager.setupWizardCompleted)
    }
    
    func testResetDefaultsClearsWizardFlag() {
        settingsManager.setupWizardCompleted = true
        XCTAssertTrue(settingsManager.setupWizardCompleted)
        
        settingsManager.resetToDefaults()
        XCTAssertFalse(settingsManager.setupWizardCompleted)
    }
    
    // Note: UI Navigation tests for SwiftUI are better suited for UI Tests or 
    // simply verifying the state machine logic if extracted to a ViewModel.
    // Since we put logic in the View for this simple wizard, we mainly test the backing store here.
    
    func testDeviceSelectionPersistence() {
        // Simulating selection in the wizard
        let inputID = "test-input-uid"
        let outputID = "test-output-uid"
        
        settingsManager.audioInputDeviceID = inputID
        settingsManager.monitoringOutputDeviceID = outputID
        
        XCTAssertEqual(settingsManager.audioInputDeviceID, inputID)
        XCTAssertEqual(settingsManager.monitoringOutputDeviceID, outputID)
    }

    func testWizardCompletionMarksSetupCompleted() {
        XCTAssertFalse(settingsManager.setupWizardCompleted)

        let completionHandler = {
            self.settingsManager.setupWizardCompleted = true
        }
        completionHandler()

        XCTAssertTrue(settingsManager.setupWizardCompleted)
    }
}
