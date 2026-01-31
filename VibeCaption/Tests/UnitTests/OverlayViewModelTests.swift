//
//  OverlayViewModelTests.swift
//  VibeCaptionTests
//
//  Tests for OverlayViewModel logic and persistence.
//

import XCTest
import Combine
@testable import VibeCaption

class OverlayViewModelTests: XCTestCase {
    
    var viewModel: OverlayViewModel!
    var mockDefaults: UserDefaults!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        // Use a temporary suite for testing to avoid touching real user defaults
        mockDefaults = UserDefaults(suiteName: "OverlayViewModelTests")
        mockDefaults.removePersistentDomain(forName: "OverlayViewModelTests")
        viewModel = OverlayViewModel(userDefaults: mockDefaults)
        cancellables = []
    }
    
    override func tearDown() {
        mockDefaults.removePersistentDomain(forName: "OverlayViewModelTests")
        viewModel = nil
        mockDefaults = nil
        cancellables = nil
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertFalse(viewModel.isVisible)
        // Check defaults are sane (either 0 or default size)
        // Since we didn't set storage, it should be default size or 0 pos
        XCTAssertEqual(viewModel.position, .zero) // Expected default for 0,0
        XCTAssertEqual(viewModel.size.width, 800)
    }
    
    func testMethods() {
        viewModel.show()
        XCTAssertTrue(viewModel.isVisible)
        
        viewModel.hide()
        XCTAssertFalse(viewModel.isVisible)
        
        viewModel.toggle()
        XCTAssertTrue(viewModel.isVisible)
    }
    
    func testPersistence() {
        // Given
        let newPos = CGPoint(x: 123, y: 456)
        let newSize = CGSize(width: 500, height: 300)
        
        let expectation = XCTestExpectation(description: "Persistence Debounce")
        
        // When
        viewModel.updatePosition(newPos)
        viewModel.updateSize(newSize)
        
        // Then - wait for debounce (0.5s) + buffer
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Verify Logic
            XCTAssertEqual(self.viewModel.position, newPos)
            XCTAssertEqual(self.viewModel.size, newSize)
            
            // Verify Persistence
            XCTAssertEqual(self.mockDefaults.double(forKey: "OverlayWindowPositionX"), 123)
            XCTAssertEqual(self.mockDefaults.double(forKey: "OverlayWindowPositionY"), 456)
            XCTAssertEqual(self.mockDefaults.double(forKey: "OverlayWindowWidth"), 500)
            XCTAssertEqual(self.mockDefaults.double(forKey: "OverlayWindowHeight"), 300)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testInitializationFromPersistence() {
        // Setup existing defaults
        mockDefaults.set(100.0, forKey: "OverlayWindowPositionX")
        mockDefaults.set(200.0, forKey: "OverlayWindowPositionY")
        mockDefaults.set(400.0, forKey: "OverlayWindowWidth")
        mockDefaults.set(100.0, forKey: "OverlayWindowHeight")
        
        // Re-init VM
        let newVM = OverlayViewModel(userDefaults: mockDefaults)
        
        XCTAssertEqual(newVM.position.x, 100)
        XCTAssertEqual(newVM.position.y, 200)
        XCTAssertEqual(newVM.size.width, 400)
        XCTAssertEqual(newVM.size.height, 100)
    }
}
