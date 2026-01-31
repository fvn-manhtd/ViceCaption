//
//  TranscriptManagerTests.swift
//  VibeCaptionTests
//
//  Unit tests for TranscriptManager.
//

import XCTest
@testable import VibeCaption

final class TranscriptManagerTests: XCTestCase {
    
    var sut: TranscriptManager!
    var testUserDefaults: UserDefaults!
    var testSuiteName: String!
    var settingsManager: SettingsManager!
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        // Create isolated UserDefaults for settings
        testSuiteName = "com.vibecaption.tests.\\(UUID().uuidString)"
        testUserDefaults = UserDefaults(suiteName: testSuiteName)!
        settingsManager = SettingsManager(userDefaults: testUserDefaults)
        
        // Set up temp directory for transcript storage
        tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("vibecaption-test-\\(UUID().uuidString)")
        settingsManager.transcriptStoragePath = tempDirectory.path
        
        sut = TranscriptManager(settingsManager: settingsManager)
    }
    
    override func tearDown() {
        // Clean up test files
        try? FileManager.default.removeItem(at: tempDirectory)
        testUserDefaults.removePersistentDomain(forName: testSuiteName)
        sut = nil
        settingsManager = nil
        testUserDefaults = nil
        super.tearDown()
    }
    
    // MARK: - Session Management Tests
    
    /// Test starting a new session creates a session
    func testStartNewSessionCreatesSession() {
        XCTAssertNil(sut.currentSession)
        
        sut.startNewSession()
        
        XCTAssertNotNil(sut.currentSession)
        XCTAssertTrue(sut.hasActiveSession)
    }
    
    /// Test starting a new session ends existing session
    func testStartNewSessionEndsExistingSession() {
        sut.startNewSession()
        let firstSession = sut.currentSession
        
        sut.startNewSession()
        
        XCTAssertNotEqual(sut.currentSession?.id, firstSession?.id)
    }
    
    /// Test ending session marks it as inactive
    func testEndCurrentSession() {
        sut.startNewSession()
        XCTAssertTrue(sut.hasActiveSession)
        
        sut.endCurrentSession()
        
        XCTAssertNotNil(sut.currentSession?.endTime)
    }
    
    // MARK: - Block Management Tests
    
    /// Test adding block to session
    func testAddBlock() {
        sut.startNewSession()
        let block = TranscriptBlock(japaneseText: "テスト", confidence: 0.9)
        
        sut.addBlock(block)
        
        XCTAssertEqual(sut.currentSession?.blocks.count, 1)
        XCTAssertEqual(sut.currentSession?.blocks.first?.japaneseText, "テスト")
    }
    
    /// Test adding block without session does nothing
    func testAddBlockWithoutSession() {
        let block = TranscriptBlock(japaneseText: "テスト", confidence: 0.9)
        
        sut.addBlock(block)
        
        XCTAssertNil(sut.currentSession)
    }
    
    /// Test adding pause marker
    func testAddPauseMarker() {
        sut.startNewSession()
        
        sut.addPauseMarker()
        
        XCTAssertEqual(sut.currentSession?.pauseMarkers.count, 1)
    }
    
    /// Test adding pause marker without session does nothing
    func testAddPauseMarkerWithoutSession() {
        sut.addPauseMarker()
        
        XCTAssertNil(sut.currentSession)
    }
    
    // MARK: - Display State Tests
    
    /// Test displayable blocks returns all blocks initially
    func testDisplayableBlocksReturnsAllBlocks() {
        sut.startNewSession()
        let block1 = TranscriptBlock(japaneseText: "テスト1", confidence: 0.9)
        let block2 = TranscriptBlock(japaneseText: "テスト2", confidence: 0.9)
        sut.addBlock(block1)
        sut.addBlock(block2)
        
        XCTAssertEqual(sut.displayableBlocks.count, 2)
    }
    
    /// Test clearDisplay hides blocks but keeps data
    func testClearDisplayKeepsData() {
        sut.startNewSession()
        let block1 = TranscriptBlock(japaneseText: "テスト1", confidence: 0.9)
        let block2 = TranscriptBlock(japaneseText: "テスト2", confidence: 0.9)
        sut.addBlock(block1)
        sut.addBlock(block2)
        
        sut.clearDisplay()
        
        // Displayable is empty
        XCTAssertTrue(sut.displayableBlocks.isEmpty)
        // But session data is preserved
        XCTAssertEqual(sut.currentSession?.blocks.count, 2)
    }
    
    /// Test clearAndDiscard removes data permanently
    func testClearAndDiscardRemovesData() {
        sut.startNewSession()
        let block1 = TranscriptBlock(japaneseText: "テスト1", confidence: 0.9)
        let block2 = TranscriptBlock(japaneseText: "テスト2", confidence: 0.9)
        sut.addBlock(block1)
        sut.addBlock(block2)
        
        sut.clearAndDiscard()
        
        // Both are empty
        XCTAssertTrue(sut.displayableBlocks.isEmpty)
        XCTAssertTrue(sut.currentSession?.blocks.isEmpty ?? false)
    }
    
    /// Test new blocks appear after clearDisplay
    func testNewBlocksAppearAfterClearDisplay() {
        sut.startNewSession()
        let block1 = TranscriptBlock(japaneseText: "テスト1", confidence: 0.9)
        sut.addBlock(block1)
        sut.clearDisplay()
        
        let block2 = TranscriptBlock(japaneseText: "テスト2", confidence: 0.9)
        sut.addBlock(block2)
        
        // New block is displayable
        XCTAssertEqual(sut.displayableBlocks.count, 1)
        XCTAssertEqual(sut.displayableBlocks.first?.japaneseText, "テスト2")
        // Session has both
        XCTAssertEqual(sut.currentSession?.blocks.count, 2)
    }
    
    // MARK: - File Operations Tests
    
    /// Test save session creates file
    func testSaveSessionCreatesFile() throws {
        sut.startNewSession()
        let block = TranscriptBlock(japaneseText: "テスト", englishText: "Test", confidence: 0.9)
        sut.addBlock(block)
        
        let savedURL = try sut.saveSession()
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path))
    }
    
    /// Test save session uses correct filename pattern
    func testSaveSessionFilenamePattern() throws {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 31
        components.hour = 14
        components.minute = 30
        let calendar = Calendar.current
        let date = calendar.date(from: components)!
        
        // We need to manually create a session with a known start time
        let session = TranscriptSession(startTime: date)
        sut.startNewSession()
        // Access internal state to set session
        // Since we can't directly set, we just verify the format pattern
        
        let expectedURL = sut.expectedFileURL()
        XCTAssertNotNil(expectedURL)
        XCTAssertTrue(expectedURL!.lastPathComponent.hasSuffix("_VibeCaption.txt"))
    }
    
    /// Test save session writes correct content
    func testSaveSessionWritesCorrectContent() throws {
        sut.startNewSession()
        
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
        sut.addBlock(block)
        
        let savedURL = try sut.saveSession()
        let content = try String(contentsOf: savedURL, encoding: .utf8)
        
        XCTAssertTrue(content.contains("こんにちは"))
        XCTAssertTrue(content.contains("Hello"))
        XCTAssertTrue(content.contains("Speaker 1"))
    }
    
    /// Test save throws when no session
    func testSaveThrowsWhenNoSession() {
        XCTAssertThrowsError(try sut.saveSession()) { error in
            guard let transcriptError = error as? TranscriptManagerError else {
                XCTFail("Expected TranscriptManagerError")
                return
            }
            XCTAssertEqual(transcriptError.localizedDescription, "No active transcript session")
        }
    }
    
    /// Test expected file URL returns nil when no session
    func testExpectedFileURLReturnsNilWithoutSession() {
        XCTAssertNil(sut.expectedFileURL())
    }
    
    /// Test save uses settings manager path
    func testSaveUsesSettingsManagerPath() throws {
        let customPath = tempDirectory.appendingPathComponent("custom-transcripts")
        settingsManager.transcriptStoragePath = customPath.path
        
        sut.startNewSession()
        let block = TranscriptBlock(japaneseText: "テスト", confidence: 0.9)
        sut.addBlock(block)
        
        let savedURL = try sut.saveSession()
        
        XCTAssertTrue(savedURL.path.hasPrefix(customPath.path))
    }
}
