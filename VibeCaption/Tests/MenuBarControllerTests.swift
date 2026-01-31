//
//  MenuBarControllerTests.swift
//  VibeCaptionTests
//
//  Unit tests for MenuBarController.
//

import XCTest
import Combine
@testable import VibeCaption

class MenuBarControllerTests: XCTestCase {
    
    var appStateManager: AppStateManager!
    var settingsManager: SettingsManager!
    var menuBarController: MenuBarController!
    
    override func setUp() {
        super.setUp()
        appStateManager = AppStateManager()
        settingsManager = SettingsManager()
        // MenuBarController initialization creates NSStatusItem, which might not be fully testable 
        // in a headless XCTest environment without UI, but we can test the logic flow 
        // if we decouple it or if the environment allows basic AppKit objects.
        // Assuming partial AppKit availability.
        menuBarController = MenuBarController(appStateManager: appStateManager, settingsManager: settingsManager)
    }
    
    override func tearDown() {
        menuBarController = nil
        appStateManager = nil
        settingsManager = nil
        super.tearDown()
    }
    
    // Helper to get menu items
    // Since privacy of properties in controller, we need reflection or exposed properties for testing.
    // For this test, we assume we can check effects on dependencies or rely on notifications.
    // However, purely UI tests are hard. Ideally we'd test the *actions* logic separately.
    // Given the simplified controller, we verify if calling actions updates state.
    
    func testToggleListeningAction() throws {
        // Given
        // We need models loaded to start listening
        appStateManager.areModelsLoaded = true
        
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
        
        // Then
        // Depending on async nature of state transition (Published), we might need expectation.
        // AppStateManager transition is synchronous though.
        XCTAssertEqual(appStateManager.currentState, .listening)
    }
    
    func testMenuStateUpdates() {
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
        // We must load models first to allow transition
        appStateManager.areModelsLoaded = true
        try? appStateManager.startListening()
        
        // Run loop briefly to allow Combine update
        let expectation = XCTestExpectation(description: "Menu update")
        DispatchQueue.main.async {
            if item.title == "Pause Listening" {
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(item.title, "Pause Listening")
        
        // Change State -> Paused
        try? appStateManager.pause()
        
        let expectation2 = XCTestExpectation(description: "Menu update 2")
        DispatchQueue.main.async {
            if item.title == "Resume Listening" {
                expectation2.fulfill()
            }
        }
        wait(for: [expectation2], timeout: 1.0)
        
        XCTAssertEqual(item.title, "Resume Listening")
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
}
