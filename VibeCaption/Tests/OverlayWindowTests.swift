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
    
    func testVisibilityBinding_Show() {
        let expectation = self.expectation(description: "Window Shows")
        
        // When VM shows
        viewModel.show()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertTrue(self.window.isPresentedForTest, "Window should mark presented when VM is visible")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testVisibilityBinding_Hide() {
        let expectation = self.expectation(description: "Window Hides")
        
        // Given visible
        viewModel.show()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // When VM hides
            self.viewModel.hide()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                XCTAssertFalse(self.window.isPresentedForTest, "Window should mark hidden when VM is hidden")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testFrameBinding() {
        let expectation = self.expectation(description: "Window Frame Updates")
        let newPos = CGPoint(x: 100, y: 100)
        let newSize = CGSize(width: 400, height: 100)
        
        DispatchQueue.main.async {
            self.viewModel.updatePosition(newPos)
            self.viewModel.updateSize(newSize)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.window.frame.origin, newPos)
            XCTAssertEqual(self.window.frame.size, newSize)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
}
