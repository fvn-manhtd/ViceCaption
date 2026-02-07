//
//  OverlayViewModelTests.swift
//  VibeCaptionTests
//
//  Tests for OverlayViewModel logic and persistence.
//

import XCTest
import Combine
@testable import VibeCaption

@MainActor
final class OverlayViewModelTests: XCTestCase {
    
    var viewModel: OverlayViewModel!
    var mockDefaults: UserDefaults!
    var cancellables: Set<AnyCancellable>!
    var suiteName: String!
    
    override func setUp() {
        super.setUp()
        // Use a temporary suite for testing to avoid touching real user defaults
        suiteName = "OverlayViewModelTests.\(UUID().uuidString)"
        mockDefaults = UserDefaults(suiteName: suiteName)
        mockDefaults.removePersistentDomain(forName: suiteName)
        viewModel = OverlayViewModel(userDefaults: mockDefaults)
        cancellables = []
    }
    
    override func tearDown() {
        mockDefaults.removePersistentDomain(forName: suiteName)
        viewModel = nil
        mockDefaults = nil
        cancellables = nil
        suiteName = nil
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
    
    func testPersistence() async throws {
        // Given
        let newPos = CGPoint(x: 123, y: 456)
        let newSize = CGSize(width: 500, height: 300)

        // When
        viewModel.updatePosition(newPos)
        viewModel.updateSize(newSize)

        // Allow main-runloop debounce persistence to flush without blocking the main thread.
        try await Task.sleep(nanoseconds: 1_500_000_000)

        // Verify Logic
        XCTAssertEqual(viewModel.position, newPos)
        XCTAssertEqual(viewModel.size, newSize)

        // Verify Persistence
        XCTAssertEqual(mockDefaults.double(forKey: "OverlayWindowPositionX"), 123)
        XCTAssertEqual(mockDefaults.double(forKey: "OverlayWindowPositionY"), 456)
        XCTAssertEqual(mockDefaults.double(forKey: "OverlayWindowWidth"), 500)
        XCTAssertEqual(mockDefaults.double(forKey: "OverlayWindowHeight"), 300)
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
