//
//  ClearCaptionsTests.swift
//  VibeCaptionTests
//
//  Unit tests for clear captions button and popup behavior.
//

import XCTest
@testable import VibeCaption

final class ClearCaptionsTests: XCTestCase {
    
    // MARK: - Clear Button Visibility Tests
    
    /// Test clear button is visible when content exists
    func testClearButtonVisibleWithContent() {
        XCTAssertTrue(OverlayControlsView.shouldShowClearButton(hasContent: true))
    }
    
    /// Test clear button is hidden when no content
    func testClearButtonHiddenWithNoContent() {
        XCTAssertFalse(OverlayControlsView.shouldShowClearButton(hasContent: false))
    }
    
    // MARK: - TranscriptManager Clear Action Tests
    
    var sut: TranscriptManager!
    var testUserDefaults: UserDefaults!
    var testSuiteName: String!
    var settingsManager: SettingsManager!
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        testSuiteName = "com.vibecaption.clearcaptionstests.\(UUID().uuidString)"
        testUserDefaults = UserDefaults(suiteName: testSuiteName)!
        settingsManager = SettingsManager(userDefaults: testUserDefaults)
        
        tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("vibecaption-cleartests-\(UUID().uuidString)")
        settingsManager.transcriptStoragePath = tempDirectory.path
        
        sut = TranscriptManager(settingsManager: settingsManager)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        testUserDefaults.removePersistentDomain(forName: testSuiteName)
        sut = nil
        settingsManager = nil
        testUserDefaults = nil
        super.tearDown()
    }
    
    /// Test clearDisplay clears UI but keeps data for saving
    func testClearDisplayOnlyKeepsDataForFile() {
        sut.startNewSession()
        let block = TranscriptBlock(japaneseText: "テスト1", confidence: 0.9)
        sut.addBlock(block)
        
        XCTAssertEqual(sut.displayableBlocks.count, 1)
        XCTAssertEqual(sut.currentSession?.blocks.count, 1)
        
        sut.clearDisplay()
        
        // Display is empty
        XCTAssertTrue(sut.displayableBlocks.isEmpty)
        // But session data is preserved
        XCTAssertEqual(sut.currentSession?.blocks.count, 1)
    }
    
    /// Test clearAndDiscard removes data permanently
    func testClearAndDiscardRemovesDataPermanently() {
        sut.startNewSession()
        let block = TranscriptBlock(japaneseText: "テスト1", confidence: 0.9)
        sut.addBlock(block)
        
        XCTAssertEqual(sut.displayableBlocks.count, 1)
        XCTAssertEqual(sut.currentSession?.blocks.count, 1)
        
        sut.clearAndDiscard()
        
        // Both display and session are empty
        XCTAssertTrue(sut.displayableBlocks.isEmpty)
        XCTAssertTrue(sut.currentSession?.blocks.isEmpty ?? false)
    }
    
    /// Test hasDisplayableContent returns correct state
    func testHasDisplayableContent() {
        sut.startNewSession()
        
        // Initially empty
        XCTAssertTrue(sut.displayableBlocks.isEmpty)
        
        // Add content
        let block = TranscriptBlock(japaneseText: "テスト", confidence: 0.9)
        sut.addBlock(block)
        XCTAssertFalse(sut.displayableBlocks.isEmpty)
        
        // Clear display
        sut.clearDisplay()
        XCTAssertTrue(sut.displayableBlocks.isEmpty)
    }
    
    /// Test new blocks appear after clearDisplay
    func testNewBlocksAppearAfterClearDisplay() {
        sut.startNewSession()
        let block1 = TranscriptBlock(japaneseText: "古い", confidence: 0.9)
        sut.addBlock(block1)
        sut.clearDisplay()
        
        let block2 = TranscriptBlock(japaneseText: "新しい", confidence: 0.9)
        sut.addBlock(block2)
        
        // Only new block is displayed
        XCTAssertEqual(sut.displayableBlocks.count, 1)
        XCTAssertEqual(sut.displayableBlocks.first?.japaneseText, "新しい")
        
        // Session has both
        XCTAssertEqual(sut.currentSession?.blocks.count, 2)
    }
    
    /// Test that cleared data is written to file
    func testClearDisplayPreservesDataInSavedFile() throws {
        sut.startNewSession()
        let block = TranscriptBlock(
            japaneseText: "保存されるテキスト",
            englishText: "Saved text",
            confidence: 0.9
        )
        sut.addBlock(block)
        
        // Clear display only
        sut.clearDisplay()
        
        // Save session
        let savedURL = try sut.saveSession()
        let content = try String(contentsOf: savedURL, encoding: .utf8)
        
        // Data should still be in file
        XCTAssertTrue(content.contains("保存されるテキスト"))
        XCTAssertTrue(content.contains("Saved text"))
    }
    
    /// Test that discarded data is NOT written to file
    func testClearAndDiscardRemovesFromSavedFile() throws {
        sut.startNewSession()
        let block = TranscriptBlock(
            japaneseText: "削除されるテキスト",
            englishText: "Deleted text",
            confidence: 0.9
        )
        sut.addBlock(block)
        
        // Clear and discard
        sut.clearAndDiscard()
        
        // Add new block so we have something to save
        let newBlock = TranscriptBlock(
            japaneseText: "残るテキスト",
            englishText: "Remaining text",
            confidence: 0.9
        )
        sut.addBlock(newBlock)
        
        // Save session
        let savedURL = try sut.saveSession()
        let content = try String(contentsOf: savedURL, encoding: .utf8)
        
        // Discarded data should NOT be in file
        XCTAssertFalse(content.contains("削除されるテキスト"))
        XCTAssertFalse(content.contains("Deleted text"))
        
        // New data should be in file
        XCTAssertTrue(content.contains("残るテキスト"))
        XCTAssertTrue(content.contains("Remaining text"))
    }
}
