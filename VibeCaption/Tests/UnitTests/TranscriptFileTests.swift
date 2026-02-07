import XCTest
@testable import VibeCaption

final class TranscriptFileTests: XCTestCase {
    private var sut: TranscriptManager!
    private var settingsManager: SettingsManager!
    private var userDefaults: UserDefaults!
    private var suiteName: String!
    private var transcriptDirectory: URL!

    override func setUp() {
        super.setUp()

        suiteName = "TranscriptFileTests_\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
        settingsManager = SettingsManager(userDefaults: userDefaults)

        transcriptDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("transcript-files-\(UUID().uuidString)", isDirectory: true)
        settingsManager.transcriptStoragePath = transcriptDirectory.path

        sut = TranscriptManager(settingsManager: settingsManager, autosaveInterval: 0)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: transcriptDirectory)
        userDefaults.removePersistentDomain(forName: suiteName)

        sut = nil
        settingsManager = nil
        userDefaults = nil
        suiteName = nil
        transcriptDirectory = nil

        super.tearDown()
    }

    func testFileIsCreatedOnSessionEnd() {
        sut.startNewSession()
        sut.addBlock(TranscriptBlock(japaneseText: "こんにちは", englishText: "Hello", confidence: 0.9))

        let savedURL = sut.endCurrentSession(trigger: .manualStop)

        XCTAssertNotNil(savedURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL!.path))
    }

    func testFilenameFormatIsCorrect() {
        sut.startNewSession()

        guard let expectedURL = sut.expectedFileURL() else {
            XCTFail("Expected file URL should exist for active session")
            return
        }

        let pattern = #"^\d{4}-\d{2}-\d{2}_\d{4}_VibeCaption\.txt$"#
        let range = expectedURL.lastPathComponent.range(of: pattern, options: .regularExpression)
        XCTAssertNotNil(range)
    }

    func testFileContentMatchesSpecFormat() throws {
        sut.startNewSession()

        let block1 = TranscriptBlock(
            timestamp: makeDate(hour: 14, minute: 3, second: 12),
            speakerLabel: "Speaker 1",
            japaneseText: "こんにちは、今日の会議を始めましょう。",
            englishText: "Hello, let's start today's meeting.",
            confidence: 0.95
        )
        let block2 = TranscriptBlock(
            timestamp: makeDate(hour: 14, minute: 3, second: 18),
            speakerLabel: "Speaker 2",
            japaneseText: "はい、よろしくお願いします。",
            englishText: "Yes, thank you for having me.",
            confidence: 0.92
        )
        let pause = PauseMarker(timestamp: makeDate(hour: 14, minute: 3, second: 25))
        let block3 = TranscriptBlock(
            timestamp: makeDate(hour: 14, minute: 5, second: 30),
            speakerLabel: "Speaker 1",
            japaneseText: "続けましょう。",
            englishText: "Let's continue.",
            confidence: 0.93
        )

        sut.addBlock(block1)
        sut.addBlock(block2)
        sut.addPauseMarker(pause)
        sut.addBlock(block3)

        guard let savedURL = sut.endCurrentSession(trigger: .manualStop) else {
            XCTFail("Expected transcript file to be saved")
            return
        }

        let content = try String(contentsOf: savedURL, encoding: .utf8)
        let expected = """
        [14:03:12] (Speaker 1)
        こんにちは、今日の会議を始めましょう。
        Hello, let's start today's meeting.

        [14:03:18] (Speaker 2)
        はい、よろしくお願いします。
        Yes, thank you for having me.

        [14:03:25] [PAUSED]

        [14:05:30] (Speaker 1)
        続けましょう。
        Let's continue.
        """

        XCTAssertEqual(content, expected)
    }

    func testEmptySessionDoesNotCreateFile() throws {
        sut.startNewSession()

        let savedURL = sut.endCurrentSession(trigger: .manualStop)

        XCTAssertNil(savedURL)
        let files = try FileManager.default.contentsOfDirectory(atPath: transcriptDirectory.path)
        XCTAssertTrue(files.isEmpty)
    }

    func testClearAndDiscardRemovesDiscardedContentFromSavedFile() throws {
        sut.startNewSession()

        sut.addBlock(TranscriptBlock(
            japaneseText: "discard me",
            englishText: "discard me english",
            confidence: 0.9
        ))
        sut.clearAndDiscard()
        sut.addBlock(TranscriptBlock(
            japaneseText: "keep me",
            englishText: "keep me english",
            confidence: 0.9
        ))

        guard let savedURL = sut.endCurrentSession(trigger: .manualStop) else {
            XCTFail("Expected transcript file to be saved")
            return
        }

        let content = try String(contentsOf: savedURL, encoding: .utf8)
        XCTAssertFalse(content.contains("discard me"))
        XCTAssertFalse(content.contains("discard me english"))
        XCTAssertTrue(content.contains("keep me"))
        XCTAssertTrue(content.contains("keep me english"))
    }

    func testSaveCreatesDirectoryWhenMissing() {
        let nestedDirectory = transcriptDirectory
            .appendingPathComponent("deep/path/to/transcripts", isDirectory: true)
        settingsManager.transcriptStoragePath = nestedDirectory.path
        try? FileManager.default.removeItem(at: nestedDirectory)

        sut.startNewSession()
        sut.addBlock(TranscriptBlock(japaneseText: "content", confidence: 0.9))

        let savedURL = sut.endCurrentSession(trigger: .manualStop)

        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: nestedDirectory.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
        XCTAssertNotNil(savedURL)
    }

    private func makeDate(hour: Int, minute: Int, second: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = 2026
        components.month = 2
        components.day = 7
        components.hour = hour
        components.minute = minute
        components.second = second
        return components.date!
    }
}
