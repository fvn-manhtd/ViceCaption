//
//  TranscriptModelsTests.swift
//  VibeCaptionTests
//
//  Unit tests for TranscriptBlock, PauseMarker, and TranscriptSession models.
//

import XCTest
@testable import VibeCaption

final class TranscriptModelsTests: XCTestCase {
    
    // MARK: - TranscriptBlock Tests
    
    /// Test creating a transcript block with all fields
    func testTranscriptBlockCreationWithAllFields() {
        let id = UUID()
        let timestamp = Date()
        let block = TranscriptBlock(
            id: id,
            timestamp: timestamp,
            speakerLabel: "Speaker 1",
            japaneseText: "こんにちは",
            englishText: "Hello",
            confidence: 0.95
        )
        
        XCTAssertEqual(block.id, id)
        XCTAssertEqual(block.timestamp, timestamp)
        XCTAssertEqual(block.speakerLabel, "Speaker 1")
        XCTAssertEqual(block.japaneseText, "こんにちは")
        XCTAssertEqual(block.englishText, "Hello")
        XCTAssertEqual(block.confidence, 0.95)
    }
    
    /// Test that isLowConfidence is true when confidence is below 0.7
    func testTranscriptBlockIsLowConfidenceTrue() {
        let block = TranscriptBlock(
            japaneseText: "テスト",
            confidence: 0.5
        )
        
        XCTAssertTrue(block.isLowConfidence)
    }
    
    /// Test that isLowConfidence is false when confidence is at or above 0.7
    func testTranscriptBlockIsLowConfidenceFalse() {
        let block = TranscriptBlock(
            japaneseText: "テスト",
            confidence: 0.7
        )
        
        XCTAssertFalse(block.isLowConfidence)
    }
    
    /// Test that isLowConfidence is false for high confidence
    func testTranscriptBlockHighConfidence() {
        let block = TranscriptBlock(
            japaneseText: "テスト",
            confidence: 0.95
        )
        
        XCTAssertFalse(block.isLowConfidence)
    }
    
    /// Test confidence value clamping to valid range
    func testTranscriptBlockConfidenceClamping() {
        let blockAbove = TranscriptBlock(
            japaneseText: "テスト",
            confidence: 1.5
        )
        XCTAssertEqual(blockAbove.confidence, 1.0)
        
        let blockBelow = TranscriptBlock(
            japaneseText: "テスト",
            confidence: -0.5
        )
        XCTAssertEqual(blockBelow.confidence, 0.0)
    }
    
    /// Test block with nil speaker label
    func testTranscriptBlockOptionalSpeaker() {
        let block = TranscriptBlock(
            japaneseText: "テスト",
            confidence: 0.9
        )
        
        XCTAssertNil(block.speakerLabel)
    }
    
    /// Test block with nil English text
    func testTranscriptBlockOptionalEnglish() {
        let block = TranscriptBlock(
            japaneseText: "テスト",
            confidence: 0.9
        )
        
        XCTAssertNil(block.englishText)
    }
    
    /// Test TranscriptBlock equatable
    func testTranscriptBlockEquatable() {
        let id = UUID()
        let timestamp = Date()
        
        let block1 = TranscriptBlock(
            id: id,
            timestamp: timestamp,
            japaneseText: "テスト",
            confidence: 0.9
        )
        
        let block2 = TranscriptBlock(
            id: id,
            timestamp: timestamp,
            japaneseText: "テスト",
            confidence: 0.9
        )
        
        XCTAssertEqual(block1, block2)
    }
    
    // MARK: - PauseMarker Tests
    
    /// Test creating a pause marker
    func testPauseMarkerCreation() {
        let id = UUID()
        let timestamp = Date()
        let marker = PauseMarker(id: id, timestamp: timestamp)
        
        XCTAssertEqual(marker.id, id)
        XCTAssertEqual(marker.timestamp, timestamp)
    }
    
    /// Test pause marker with default values
    func testPauseMarkerDefaults() {
        let marker = PauseMarker()
        
        XCTAssertNotNil(marker.id)
        XCTAssertNotNil(marker.timestamp)
    }
    
    /// Test PauseMarker equatable
    func testPauseMarkerEquatable() {
        let id = UUID()
        let timestamp = Date()
        
        let marker1 = PauseMarker(id: id, timestamp: timestamp)
        let marker2 = PauseMarker(id: id, timestamp: timestamp)
        
        XCTAssertEqual(marker1, marker2)
    }
    
    // MARK: - TranscriptSession Tests
    
    /// Test creating a session
    func testTranscriptSessionCreation() {
        let id = UUID()
        let startTime = Date()
        let session = TranscriptSession(id: id, startTime: startTime)
        
        XCTAssertEqual(session.id, id)
        XCTAssertEqual(session.startTime, startTime)
        XCTAssertNil(session.endTime)
        XCTAssertTrue(session.blocks.isEmpty)
        XCTAssertTrue(session.pauseMarkers.isEmpty)
        XCTAssertTrue(session.isActive)
    }
    
    /// Test adding a block to a session
    func testTranscriptSessionAddBlock() {
        var session = TranscriptSession()
        let block = TranscriptBlock(japaneseText: "テスト", confidence: 0.9)
        
        session.addBlock(block)
        
        XCTAssertEqual(session.blocks.count, 1)
        XCTAssertEqual(session.blocks.first?.japaneseText, "テスト")
    }
    
    /// Test adding a pause marker to a session
    func testTranscriptSessionAddPauseMarker() {
        var session = TranscriptSession()
        let marker = PauseMarker()
        
        session.addPauseMarker(marker)
        
        XCTAssertEqual(session.pauseMarkers.count, 1)
    }
    
    /// Test ending a session sets endTime
    func testTranscriptSessionEndSession() {
        var session = TranscriptSession()
        XCTAssertNil(session.endTime)
        XCTAssertTrue(session.isActive)
        
        session.endSession()
        
        XCTAssertNotNil(session.endTime)
        XCTAssertFalse(session.isActive)
    }
    
    /// Test ending a session with specific time
    func testTranscriptSessionEndSessionAtTime() {
        var session = TranscriptSession()
        let endDate = Date().addingTimeInterval(3600) // 1 hour later
        
        session.endSession(at: endDate)
        
        XCTAssertEqual(session.endTime, endDate)
    }
    
    /// Test session totalItemCount
    func testTranscriptSessionTotalItemCount() {
        var session = TranscriptSession()
        let block = TranscriptBlock(japaneseText: "テスト", confidence: 0.9)
        let marker = PauseMarker()
        
        session.addBlock(block)
        session.addBlock(block)
        session.addPauseMarker(marker)
        
        XCTAssertEqual(session.totalItemCount, 3)
    }
    
    /// Test removing blocks from index
    func testTranscriptSessionRemoveBlocks() {
        var session = TranscriptSession()
        let block1 = TranscriptBlock(japaneseText: "テスト1", confidence: 0.9)
        let block2 = TranscriptBlock(japaneseText: "テスト2", confidence: 0.9)
        let block3 = TranscriptBlock(japaneseText: "テスト3", confidence: 0.9)
        
        session.addBlock(block1)
        session.addBlock(block2)
        session.addBlock(block3)
        XCTAssertEqual(session.blocks.count, 3)
        
        session.removeBlocks(fromIndex: 1)
        
        XCTAssertEqual(session.blocks.count, 1)
        XCTAssertEqual(session.blocks.first?.japaneseText, "テスト1")
    }
    
    /// Test clearAll removes all data
    func testTranscriptSessionClearAll() {
        var session = TranscriptSession()
        session.addBlock(TranscriptBlock(japaneseText: "テスト", confidence: 0.9))
        session.addPauseMarker(PauseMarker())
        
        session.clearAll()
        
        XCTAssertTrue(session.blocks.isEmpty)
        XCTAssertTrue(session.pauseMarkers.isEmpty)
    }
    
    /// Test session duration
    func testTranscriptSessionDuration() {
        let startTime = Date()
        var session = TranscriptSession(startTime: startTime)
        
        let endTime = startTime.addingTimeInterval(120) // 2 minutes
        session.endSession(at: endTime)
        
        XCTAssertEqual(session.duration, 120, accuracy: 0.1)
    }
}
