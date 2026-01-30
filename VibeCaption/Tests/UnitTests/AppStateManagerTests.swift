//
//  AppStateManagerTests.swift
//  VibeCaptionTests
//
//  Comprehensive unit tests for AppStateManager state transitions.
//

import XCTest
@testable import VibeCaption

final class AppStateManagerTests: XCTestCase {
    
    var sut: AppStateManager!
    
    override func setUp() {
        super.setUp()
        sut = AppStateManager()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    /// Test that the initial state is idle
    func testInitialStateIsIdle() {
        XCTAssertEqual(sut.currentState, .idle)
    }
    
    /// Test that models are not loaded by default
    func testModelsNotLoadedByDefault() {
        XCTAssertFalse(sut.areModelsLoaded)
    }
    
    /// Test that overlay is not visible by default
    func testOverlayNotVisibleByDefault() {
        XCTAssertFalse(sut.isOverlayVisible)
    }
    
    // MARK: - startListening() Tests
    
    /// Test that startListening throws when models not loaded
    func testStartListeningThrowsWhenModelsNotLoaded() {
        XCTAssertThrowsError(try sut.startListening()) { error in
            XCTAssertEqual(error as? StateTransitionError, .modelsNotLoaded)
        }
        XCTAssertEqual(sut.currentState, .idle)
    }
    
    /// Test successful startListening from idle when models loaded
    func testStartListeningSucceedsWhenModelsLoaded() throws {
        sut.areModelsLoaded = true
        
        try sut.startListening()
        
        XCTAssertEqual(sut.currentState, .listening)
    }
    
    /// Test startListening throws when already listening
    func testStartListeningThrowsWhenAlreadyListening() throws {
        sut.areModelsLoaded = true
        try sut.startListening()
        
        XCTAssertThrowsError(try sut.startListening()) { error in
            guard case .invalidTransition(from: .listening, to: .listening) = error as? StateTransitionError else {
                XCTFail("Expected invalidTransition error")
                return
            }
        }
    }
    
    // MARK: - stopListening() Tests
    
    /// Test stopListening transitions to idle from listening
    func testStopListeningFromListening() throws {
        sut.areModelsLoaded = true
        try sut.startListening()
        
        sut.stopListening()
        
        XCTAssertEqual(sut.currentState, .idle)
    }
    
    /// Test stopListening from idle does nothing (no crash)
    func testStopListeningFromIdleIsNoOp() {
        sut.stopListening()
        
        XCTAssertEqual(sut.currentState, .idle)
    }
    
    /// Test stopListening from paused returns to idle
    func testStopListeningFromPaused() throws {
        sut.areModelsLoaded = true
        try sut.startListening()
        try sut.pause()
        
        sut.stopListening()
        
        XCTAssertEqual(sut.currentState, .idle)
    }
    
    // MARK: - pause() Tests
    
    /// Test pause from listening succeeds
    func testPauseFromListening() throws {
        sut.areModelsLoaded = true
        try sut.startListening()
        
        try sut.pause()
        
        XCTAssertEqual(sut.currentState, .paused)
    }
    
    /// Test pause from translating succeeds
    func testPauseFromTranslating() throws {
        sut.areModelsLoaded = true
        try sut.startListening()
        try sut.beginTranslation()
        
        try sut.pause()
        
        XCTAssertEqual(sut.currentState, .paused)
    }
    
    /// Test pause throws when idle
    func testPauseThrowsWhenIdle() {
        XCTAssertThrowsError(try sut.pause()) { error in
            XCTAssertEqual(error as? StateTransitionError, .notPausable)
        }
    }
    
    /// Test pause throws when already paused
    func testPauseThrowsWhenAlreadyPaused() throws {
        sut.areModelsLoaded = true
        try sut.startListening()
        try sut.pause()
        
        XCTAssertThrowsError(try sut.pause()) { error in
            XCTAssertEqual(error as? StateTransitionError, .notPausable)
        }
    }
    
    // MARK: - resume() Tests
    
    /// Test resume from paused succeeds
    func testResumeFromPaused() throws {
        sut.areModelsLoaded = true
        try sut.startListening()
        try sut.pause()
        
        try sut.resume()
        
        XCTAssertEqual(sut.currentState, .listening)
    }
    
    /// Test resume throws when not paused
    func testResumeThrowsWhenNotPaused() {
        XCTAssertThrowsError(try sut.resume()) { error in
            XCTAssertEqual(error as? StateTransitionError, .notPaused)
        }
    }
    
    /// Test resume throws when listening
    func testResumeThrowsWhenListening() throws {
        sut.areModelsLoaded = true
        try sut.startListening()
        
        XCTAssertThrowsError(try sut.resume()) { error in
            XCTAssertEqual(error as? StateTransitionError, .notPaused)
        }
    }
    
    // MARK: - toggleListening() Tests
    
    /// Test toggleListening from idle starts listening
    func testToggleFromIdleStartsListening() throws {
        sut.areModelsLoaded = true
        
        try sut.toggleListening()
        
        XCTAssertEqual(sut.currentState, .listening)
    }
    
    /// Test toggleListening from idle throws if models not loaded
    func testToggleFromIdleThrowsIfModelsNotLoaded() {
        XCTAssertThrowsError(try sut.toggleListening()) { error in
            XCTAssertEqual(error as? StateTransitionError, .modelsNotLoaded)
        }
    }
    
    /// Test toggleListening from listening pauses
    func testToggleFromListeningPauses() throws {
        sut.areModelsLoaded = true
        try sut.startListening()
        
        try sut.toggleListening()
        
        XCTAssertEqual(sut.currentState, .paused)
    }
    
    /// Test toggleListening from translating pauses
    func testToggleFromTranslatingPauses() throws {
        sut.areModelsLoaded = true
        try sut.startListening()
        try sut.beginTranslation()
        
        try sut.toggleListening()
        
        XCTAssertEqual(sut.currentState, .paused)
    }
    
    /// Test toggleListening from paused resumes
    func testToggleFromPausedResumes() throws {
        sut.areModelsLoaded = true
        try sut.startListening()
        try sut.pause()
        
        try sut.toggleListening()
        
        XCTAssertEqual(sut.currentState, .listening)
    }
    
    // MARK: - Translation State Tests
    
    /// Test beginTranslation from listening succeeds
    func testBeginTranslationFromListening() throws {
        sut.areModelsLoaded = true
        try sut.startListening()
        
        try sut.beginTranslation()
        
        XCTAssertEqual(sut.currentState, .translating)
    }
    
    /// Test beginTranslation throws from idle
    func testBeginTranslationThrowsFromIdle() {
        XCTAssertThrowsError(try sut.beginTranslation()) { error in
            guard case .invalidTransition(from: .idle, to: .translating) = error as? StateTransitionError else {
                XCTFail("Expected invalidTransition error")
                return
            }
        }
    }
    
    /// Test endTranslation from translating returns to listening
    func testEndTranslationReturnsToListening() throws {
        sut.areModelsLoaded = true
        try sut.startListening()
        try sut.beginTranslation()
        
        try sut.endTranslation()
        
        XCTAssertEqual(sut.currentState, .listening)
    }
    
    // MARK: - State Change Callback Tests
    
    /// Test state change callback is invoked
    func testStateChangeCallbackInvoked() throws {
        var callbackInvoked = false
        var receivedOldState: AppState?
        var receivedNewState: AppState?
        
        sut.onStateChange = { old, new in
            callbackInvoked = true
            receivedOldState = old
            receivedNewState = new
        }
        sut.areModelsLoaded = true
        
        try sut.startListening()
        
        XCTAssertTrue(callbackInvoked)
        XCTAssertEqual(receivedOldState, .idle)
        XCTAssertEqual(receivedNewState, .listening)
    }
    
    /// Test callback invoked for each transition
    func testCallbackInvokedForEachTransition() throws {
        var transitionCount = 0
        
        sut.onStateChange = { _, _ in
            transitionCount += 1
        }
        sut.areModelsLoaded = true
        
        try sut.startListening()  // 1: idle -> listening
        try sut.pause()           // 2: listening -> paused
        try sut.resume()          // 3: paused -> listening
        sut.stopListening()       // 4: listening -> idle
        
        XCTAssertEqual(transitionCount, 4)
    }
    
    // MARK: - Overlay Visibility Tests
    
    /// Test overlay visibility preservation
    func testOverlayVisibilityTracking() {
        sut.overlayWillShow()
        XCTAssertTrue(sut.isOverlayVisible)
        
        sut.overlayWillHide()
        XCTAssertFalse(sut.isOverlayVisible)
    }
    
    /// Test state is preserved when overlay hidden
    func testStatePreservedWhenOverlayHidden() throws {
        sut.areModelsLoaded = true
        try sut.startListening()
        
        sut.overlayWillHide()
        
        XCTAssertEqual(sut.preservedState, .listening)
    }
    
    /// Test preserved state available after overlay shown
    func testPreservedStateAvailableAfterShow() throws {
        sut.areModelsLoaded = true
        try sut.startListening()
        sut.overlayWillHide()
        
        sut.overlayWillShow()
        
        XCTAssertEqual(sut.preservedState, .listening)
    }
    
    // MARK: - AppState Property Tests
    
    /// Test isCapturing property for all states
    func testIsCapturingProperty() {
        XCTAssertFalse(AppState.idle.isCapturing)
        XCTAssertTrue(AppState.listening.isCapturing)
        XCTAssertTrue(AppState.translating.isCapturing)
        XCTAssertFalse(AppState.paused.isCapturing)
    }
    
    /// Test isProcessing property for all states
    func testIsProcessingProperty() {
        XCTAssertFalse(AppState.idle.isProcessing)
        XCTAssertTrue(AppState.listening.isProcessing)
        XCTAssertTrue(AppState.translating.isProcessing)
        XCTAssertFalse(AppState.paused.isProcessing)
    }
    
    /// Test canStartListening property for all states
    func testCanStartListeningProperty() {
        XCTAssertTrue(AppState.idle.canStartListening)
        XCTAssertFalse(AppState.listening.canStartListening)
        XCTAssertFalse(AppState.translating.canStartListening)
        XCTAssertTrue(AppState.paused.canStartListening)
    }
    
    /// Test canPause property for all states
    func testCanPauseProperty() {
        XCTAssertFalse(AppState.idle.canPause)
        XCTAssertTrue(AppState.listening.canPause)
        XCTAssertTrue(AppState.translating.canPause)
        XCTAssertFalse(AppState.paused.canPause)
    }
    
    /// Test display names exist for all states
    func testDisplayNames() {
        for state in AppState.allCases {
            XCTAssertFalse(state.displayName.isEmpty)
            XCTAssertFalse(state.description.isEmpty)
        }
    }
}
