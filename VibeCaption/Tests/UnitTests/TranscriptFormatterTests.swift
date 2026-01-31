//
//  TranscriptFormatterTests.swift
//  VibeCaptionTests
//
//  Unit tests for TranscriptFormatter.
//

import XCTest
@testable import VibeCaption

final class TranscriptFormatterTests: XCTestCase {
    
    var sut: TranscriptFormatter!
    
    override func setUp() {
        super.setUp()
        sut = TranscriptFormatter()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Timestamp Formatting Tests
    
    /// Test timestamp formatting produces HH:MM:SS format
    func testFormatTimestamp() {
        // Create a date at 14:30:45
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 31
        components.hour = 14
        components.minute = 30
        components.second = 45
        let calendar = Calendar.current
        let date = calendar.date(from: components)!
        
        let result = sut.formatTimestamp(date)
        
        XCTAssertEqual(result, "14:30:45")
    }
    
    /// Test timestamp formatting with leading zeros
    func testFormatTimestampWithLeadingZeros() {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 31
        components.hour = 9
        components.minute = 5
        components.second = 3
        let calendar = Calendar.current
        let date = calendar.date(from: components)!
        
        let result = sut.formatTimestamp(date)
        
        XCTAssertEqual(result, "09:05:03")
    }
    
    // MARK: - File Format Tests
    
    /// Test file format with speaker label
    func testFormatBlockForFileWithSpeaker() {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 31
        components.hour = 10
        components.minute = 30
        components.second = 0
        let calendar = Calendar.current
        let date = calendar.date(from: components)!
        
        let block = TranscriptBlock(
            timestamp: date,
            speakerLabel: "Speaker 1",
            japaneseText: "こんにちは",
            englishText: "Hello",
            confidence: 0.95
        )
        
        let result = sut.formatBlockForFile(block)
        
        let expected = "[10:30:00] (Speaker 1)\nこんにちは\nHello"
        XCTAssertEqual(result, expected)
    }
    
    /// Test file format without speaker label
    func testFormatBlockForFileWithoutSpeaker() {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 31
        components.hour = 10
        components.minute = 30
        components.second = 0
        let calendar = Calendar.current
        let date = calendar.date(from: components)!
        
        let block = TranscriptBlock(
            timestamp: date,
            speakerLabel: nil,
            japaneseText: "こんにちは",
            englishText: "Hello",
            confidence: 0.95
        )
        
        let result = sut.formatBlockForFile(block)
        
        let expected = "[10:30:00]\nこんにちは\nHello"
        XCTAssertEqual(result, expected)
    }
    
    /// Test file format without English translation
    func testFormatBlockForFileWithoutEnglish() {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 31
        components.hour = 10
        components.minute = 30
        components.second = 0
        let calendar = Calendar.current
        let date = calendar.date(from: components)!
        
        let block = TranscriptBlock(
            timestamp: date,
            speakerLabel: "Speaker 1",
            japaneseText: "こんにちは",
            englishText: nil,
            confidence: 0.95
        )
        
        let result = sut.formatBlockForFile(block)
        
        let expected = "[10:30:00] (Speaker 1)\nこんにちは"
        XCTAssertEqual(result, expected)
    }
    
    /// Test pause marker file format
    func testFormatMarkerForFile() {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 31
        components.hour = 10
        components.minute = 35
        components.second = 0
        let calendar = Calendar.current
        let date = calendar.date(from: components)!
        
        let marker = PauseMarker(timestamp: date)
        
        let result = sut.formatMarkerForFile(marker)
        
        XCTAssertEqual(result, "[10:35:00] [PAUSED]")
    }
    
    /// Test session file format with multiple blocks
    func testFormatForFileWithMultipleBlocks() {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 31
        components.hour = 10
        components.minute = 30
        components.second = 0
        let calendar = Calendar.current
        let date1 = calendar.date(from: components)!
        
        components.minute = 31
        let date2 = calendar.date(from: components)!
        
        let block1 = TranscriptBlock(
            timestamp: date1,
            speakerLabel: "Speaker 1",
            japaneseText: "こんにちは",
            englishText: "Hello",
            confidence: 0.95
        )
        
        let block2 = TranscriptBlock(
            timestamp: date2,
            speakerLabel: "Speaker 2",
            japaneseText: "おはよう",
            englishText: "Good morning",
            confidence: 0.9
        )
        
        var session = TranscriptSession()
        session.addBlock(block1)
        session.addBlock(block2)
        
        let result = sut.formatForFile(session: session)
        
        let expected = """
        [10:30:00] (Speaker 1)
        こんにちは
        Hello
        
        [10:31:00] (Speaker 2)
        おはよう
        Good morning
        """
        XCTAssertEqual(result, expected)
    }
    
    /// Test session file format with pause marker
    func testFormatForFileWithPauseMarker() {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 31
        components.hour = 10
        components.minute = 30
        components.second = 0
        let calendar = Calendar.current
        let date1 = calendar.date(from: components)!
        
        components.minute = 31
        let pauseDate = calendar.date(from: components)!
        
        components.minute = 32
        let date2 = calendar.date(from: components)!
        
        let block1 = TranscriptBlock(
            timestamp: date1,
            speakerLabel: "Speaker 1",
            japaneseText: "こんにちは",
            englishText: "Hello",
            confidence: 0.95
        )
        
        let pauseMarker = PauseMarker(timestamp: pauseDate)
        
        let block2 = TranscriptBlock(
            timestamp: date2,
            speakerLabel: "Speaker 1",
            japaneseText: "おはよう",
            englishText: "Good morning",
            confidence: 0.9
        )
        
        var session = TranscriptSession()
        session.addBlock(block1)
        session.addPauseMarker(pauseMarker)
        session.addBlock(block2)
        
        let result = sut.formatForFile(session: session)
        
        let expected = """
        [10:30:00] (Speaker 1)
        こんにちは
        Hello
        
        [10:31:00] [PAUSED]
        
        [10:32:00] (Speaker 1)
        おはよう
        Good morning
        """
        XCTAssertEqual(result, expected)
    }
    
    // MARK: - Filename Generation Tests
    
    /// Test filename generation pattern
    func testGenerateFilename() {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 31
        components.hour = 14
        components.minute = 30
        components.second = 0
        let calendar = Calendar.current
        let date = calendar.date(from: components)!
        
        let session = TranscriptSession(startTime: date)
        
        let result = sut.generateFilename(for: session)
        
        XCTAssertEqual(result, "2026-01-31_1430_VibeCaption.txt")
    }
    
    /// Test filename generation with date
    func testGenerateFilenameForDate() {
        var components = DateComponents()
        components.year = 2026
        components.month = 12
        components.day = 25
        components.hour = 9
        components.minute = 5
        let calendar = Calendar.current
        let date = calendar.date(from: components)!
        
        let result = sut.generateFilename(for: date)
        
        XCTAssertEqual(result, "2026-12-25_0905_VibeCaption.txt")
    }
    
    // MARK: - Display Formatting Tests
    
    /// Test display formatting returns AttributedString
    func testFormatForDisplayReturnsAttributedString() {
        let block = TranscriptBlock(
            japaneseText: "こんにちは",
            englishText: "Hello",
            confidence: 0.95
        )
        
        let result = sut.formatForDisplay(block: block)
        
        XCTAssertFalse(String(result.characters).isEmpty)
    }
    
    /// Test display formatting for pause marker
    func testFormatForDisplayPauseMarker() {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 31
        components.hour = 10
        components.minute = 30
        components.second = 0
        let calendar = Calendar.current
        let date = calendar.date(from: components)!
        
        let marker = PauseMarker(timestamp: date)
        
        let result = sut.formatForDisplay(marker: marker)
        
        let text = String(result.characters)
        XCTAssertTrue(text.contains("[PAUSED]"))
        XCTAssertTrue(text.contains("10:30:00"))
    }
}
