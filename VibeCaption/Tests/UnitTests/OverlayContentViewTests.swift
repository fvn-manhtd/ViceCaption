//
//  OverlayContentViewTests.swift
//  VibeCaptionTests
//
//  UI-ish unit tests for overlay content rendering logic.
//

import XCTest
@testable import VibeCaption

final class OverlayContentViewTests: XCTestCase {
    
    func testCaptionBlockRendersAllComponents() {
        // Given
        let date = Date(timeIntervalSince1970: 0) // 00:00:00 UTC
        let block = TranscriptBlock(
            id: UUID(),
            timestamp: date,
            speakerLabel: "Speaker 1",
            japaneseText: "こんにちは",
            englishText: "Hello",
            confidence: 0.95
        )
        let formatter = TranscriptFormatter()
        let comps = CaptionBlockView.testComponents(for: block, formatter: formatter, fontSize: .medium)
        
        // Then
        XCTAssertEqual(comps.speaker, "Speaker 1")
        XCTAssertEqual(comps.timestamp, formatter.formatTimestamp(date))
        XCTAssertEqual(comps.japanese, "こんにちは")
        XCTAssertEqual(comps.englishOrPlaceholder, "Hello")
        XCTAssertFalse(comps.isLowConfidence)
        XCTAssertEqual(comps.fontPointSize, FontSize.medium.fontSize)
    }
    
    func testFontSizeUpdatesFromSettings() {
        let small = OverlayLayoutConfig.lineHeight(for: .small)
        let medium = OverlayLayoutConfig.lineHeight(for: .medium)
        let large = OverlayLayoutConfig.lineHeight(for: .large)
        
        XCTAssertTrue(small < medium)
        XCTAssertTrue(medium < large)
    }
    
    func testScrollLatestIDComputation() {
        let settings = SettingsManager(userDefaults: UserDefaults(suiteName: "OverlayContentViewTests_scroll")!)
        let manager = TranscriptManager(settingsManager: settings)
        manager.startNewSession()
        
        let b1 = TranscriptBlock(japaneseText: "一", confidence: 0.9)
        let b2 = TranscriptBlock(japaneseText: "二", confidence: 0.9)
        let b3 = TranscriptBlock(japaneseText: "三", confidence: 0.9)
        
        manager.addBlock(b1)
        manager.addBlock(b2)
        manager.addBlock(b3)
        
        let lastID = OverlayLayoutConfig.latestID(in: manager.displayableBlocks)
        XCTAssertEqual(lastID, b3.id)
    }
    
    func testLowConfidenceStyling() {
        let low = TranscriptBlock(japaneseText: "低信頼", confidence: 0.3)
        let comps = CaptionBlockView.testComponents(for: low, fontSize: .medium)
        XCTAssertTrue(comps.isLowConfidence)
    }
    
    func testMissingEnglishTextPlaceholder() {
        let noEN = TranscriptBlock(japaneseText: "テキスト", englishText: nil, confidence: 0.9)
        let comps = CaptionBlockView.testComponents(for: noEN, fontSize: .medium)
        XCTAssertEqual(comps.englishOrPlaceholder, "Translating…")
    }
}

