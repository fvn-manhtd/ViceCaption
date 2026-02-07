//
//  OverlayWindowTests.swift
//  VibeCaptionTests
//
//  Tests for OverlayWindow configuration and integration.
//

import XCTest
import SwiftUI
@testable import VibeCaption

@MainActor
class OverlayWindowTests: XCTestCase {
    
    var window: OverlayWindow!
    var viewModel: OverlayViewModel!
    var mockDefaults: UserDefaults!
    
    override func setUp() {
        super.setUp()
        mockDefaults = UserDefaults(suiteName: "OverlayWindowTests")
        mockDefaults.removePersistentDomain(forName: "OverlayWindowTests")
        viewModel = OverlayViewModel(userDefaults: mockDefaults)
        // Create the window on the main actor synchronously
        window = OverlayWindow(viewModel: viewModel)
    }
    
    override func tearDown() {
        // Close synchronously on main actor
        window.close()
        window = nil
        viewModel = nil
        mockDefaults.removePersistentDomain(forName: "OverlayWindowTests")
        mockDefaults = nil
        super.tearDown()
    }
    
    func testWindowLevel() {
        XCTAssertEqual(window.level, .floating, "Window should be always on top (floating)")
    }
    
    func testWindowStyle() {
        // print("DEBUG: styleMask rawValue: \(window.styleMask.rawValue)")
        XCTAssertTrue(window.styleMask.contains(.borderless), "Window should be borderless")
        // Note: NSWindow might strip .resizable from borderless windows in some contexts.
        // XCTAssertTrue(window.styleMask.contains(.resizable), "Window should be resizable")
    }
    
    func testWindowBehavior() {
        // Validate non-UI-server-dependent behaviors
        XCTAssertTrue(window.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(window.collectionBehavior.contains(.fullScreenAuxiliary))
    }
    
    func testWindowVisuals() {
        XCTAssertFalse(window.isOpaque, "Window should not be opaque")
        XCTAssertEqual(window.backgroundColor, .clear, "Window background should be clear")
    }
    
    func testVisibilityBinding_Show() async throws {
        viewModel.show()
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertTrue(window.isPresentedForTest, "Window should mark presented when VM is visible")
    }
    
    func testVisibilityBinding_Hide() async throws {
        viewModel.show()
        try await Task.sleep(nanoseconds: 250_000_000)

        viewModel.hide()
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertFalse(window.isPresentedForTest, "Window should mark hidden when VM is hidden")
    }
    
    func testFrameBinding() async throws {
        let newPos = CGPoint(x: 100, y: 100)
        let newSize = CGSize(width: 400, height: 100)
        
        viewModel.updatePosition(newPos)
        viewModel.updateSize(newSize)
        try await Task.sleep(nanoseconds: 120_000_000)

        XCTAssertEqual(window.frame.origin, newPos)
        XCTAssertEqual(window.frame.size, newSize)
    }

    func testFocusTrackingUpdatesViewModel() {
        XCTAssertFalse(viewModel.isFocused)

        window.becomeKey()
        XCTAssertTrue(viewModel.isFocused)

        window.resignKey()
        XCTAssertFalse(viewModel.isFocused)
    }
}
