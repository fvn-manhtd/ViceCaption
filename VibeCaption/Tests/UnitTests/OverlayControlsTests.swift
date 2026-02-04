//
//  OverlayControlsTests.swift
//  VibeCaptionTests
//
//  Tests for overlay controls logic.
//

import XCTest
import AppKit
@testable import VibeCaption

@MainActor
final class OverlayControlsTests: XCTestCase {
    func testStatusDotStylesMatchStates() {
        XCTAssertEqual(StatusDotView.style(for: .idle), .idle)
        XCTAssertEqual(StatusDotView.style(for: .listening), .listening)
        XCTAssertEqual(StatusDotView.style(for: .translating), .translating)
        XCTAssertEqual(StatusDotView.style(for: .paused), .paused)
    }
    
    func testPauseButtonVisibilityStates() {
        XCTAssertTrue(OverlayControlsView.shouldShowPauseButton(for: .listening))
        XCTAssertTrue(OverlayControlsView.shouldShowPauseButton(for: .translating))
        XCTAssertFalse(OverlayControlsView.shouldShowPauseButton(for: .idle))
        XCTAssertFalse(OverlayControlsView.shouldShowPauseButton(for: .paused))
    }
    
    func testPausedLabelVisibility() {
        XCTAssertTrue(OverlayControlsView.shouldShowPausedLabel(for: .paused))
        XCTAssertFalse(OverlayControlsView.shouldShowPausedLabel(for: .idle))
        XCTAssertFalse(OverlayControlsView.shouldShowPausedLabel(for: .listening))
    }
    
    func testSpaceKeyTriggersToggleWhenFocused() {
        let event = try! XCTUnwrap(makeKeyEvent(characters: " ", keyCode: 49))
        var toggled = false
        let handled = OverlayKeyCommandHandler.handleKeyDown(event, isFocused: true) {
            toggled = true
        }
        XCTAssertTrue(handled)
        XCTAssertTrue(toggled)
    }
    
    func testSpaceKeyIgnoredWhenNotFocused() {
        let event = try! XCTUnwrap(makeKeyEvent(characters: " ", keyCode: 49))
        var toggled = false
        let handled = OverlayKeyCommandHandler.handleKeyDown(event, isFocused: false) {
            toggled = true
        }
        XCTAssertFalse(handled)
        XCTAssertFalse(toggled)
    }
    
    func testAutoHideLogicUsesInactivityInterval() {
        let base = Date()
        let controller = OverlayAutoHideController(inactivityInterval: 30, lastActivity: base)
        XCTAssertFalse(controller.shouldHide(now: base.addingTimeInterval(10)))
        XCTAssertTrue(controller.shouldHide(now: base.addingTimeInterval(31)))
    }
    
    func testAutoHideUpdatesWithActivity() {
        let controller = OverlayAutoHideController(inactivityInterval: 5)
        let start = Date(timeIntervalSince1970: 100)
        controller.recordActivity(date: start)
        XCTAssertFalse(controller.shouldHide(now: start.addingTimeInterval(4)))
        controller.recordActivity(date: start.addingTimeInterval(4))
        XCTAssertFalse(controller.shouldHide(now: start.addingTimeInterval(8)))
        XCTAssertTrue(controller.shouldHide(now: start.addingTimeInterval(10)))
    }
    
    func testAutoHideDisabledWhenIntervalZero() {
        let controller = OverlayAutoHideController(inactivityInterval: 0)
        controller.recordActivity(date: Date(timeIntervalSince1970: 0))
        XCTAssertFalse(controller.shouldHide(now: Date(timeIntervalSince1970: 100)))
    }
    
    private func makeKeyEvent(characters: String, keyCode: UInt16) -> NSEvent? {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: keyCode
        )
    }
}
