//
//  UpdateManagerTests.swift
//  VibeCaptionTests
//
//  Tests for app update and model update detection behavior.
//

import XCTest
@testable import VibeCaption

final class UpdateManagerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var settingsManager: SettingsManager!

    override func setUp() {
        super.setUp()
        suiteName = "com.vibecaption.tests.updates.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        settingsManager = SettingsManager(userDefaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        settingsManager = nil
        super.tearDown()
    }

    func testManualCheckTriggersUpdateDriverAndPersistsTimestamp() {
        let driver = MockAppUpdateDriver()
        let fixedNow = Date(timeIntervalSince1970: 1_706_764_800) // January 30, 2024
        let manager = UpdateManager(
            settingsManager: settingsManager,
            updateDriver: driver,
            bundle: Bundle(for: Self.self),
            now: { fixedNow }
        )

        manager.checkForAppUpdates()

        XCTAssertEqual(driver.checkForUpdatesCallCount, 1)
        XCTAssertEqual(manager.lastCheckedAt, fixedNow)
        XCTAssertEqual(settingsManager.appLastUpdateCheckDate, fixedNow)
    }

    func testAutoUpdateSettingPersistsAndUpdatesDriver() {
        let driver = MockAppUpdateDriver()
        let manager = UpdateManager(settingsManager: settingsManager, updateDriver: driver, bundle: Bundle(for: Self.self))

        manager.setAutomaticAppUpdatesEnabled(false)

        XCTAssertFalse(driver.automaticallyChecksForUpdates)
        XCTAssertFalse(settingsManager.autoAppUpdatesEnabled)
        let restored = SettingsManager(userDefaults: defaults)
        XCTAssertFalse(restored.autoAppUpdatesEnabled)
    }

    func testModelUpdateDetectionFindsInstalledOutdatedModel() {
        let currentModel = ModelInfo(
            id: "whisper",
            displayName: "Whisper",
            version: "1.0.0",
            downloadURL: URL(string: "https://example.com/whisper-1.0.0.bin")!,
            checksum: "abc123",
            sizeBytes: 1_000,
            isRequired: true
        )
        let latestModel = ModelInfo(
            id: "whisper",
            displayName: "Whisper",
            version: "1.2.0",
            downloadURL: URL(string: "https://example.com/whisper-1.2.0.bin")!,
            checksum: "def456",
            sizeBytes: 1_200,
            isRequired: true
        )

        let updates = ModelManager.detectModelUpdates(
            currentCatalog: [currentModel],
            latestCatalog: [latestModel],
            installedStatuses: ["whisper": .downloaded]
        )

        XCTAssertEqual(updates.count, 1)
        XCTAssertEqual(updates.first?.currentVersion, "1.0.0")
        XCTAssertEqual(updates.first?.latestVersion, "1.2.0")
    }

    func testVersionComparisonLogic() {
        XCTAssertEqual(ModelManager.compareVersions("1.10.0", "1.2.0"), .orderedDescending)
        XCTAssertEqual(ModelManager.compareVersions("2.0", "2.0.0"), .orderedSame)
        XCTAssertEqual(ModelManager.compareVersions("3.0-beta", "3.0"), .orderedAscending)
        XCTAssertEqual(ModelManager.compareVersions("1.0.1", "1.0.9"), .orderedAscending)
    }
}

private final class MockAppUpdateDriver: AppUpdateDriverProtocol {
    var automaticallyChecksForUpdates: Bool = true
    var updateCheckInterval: TimeInterval = 60 * 60 * 24
    var lastUpdateCheckDate: Date?
    private(set) var checkForUpdatesCallCount: Int = 0

    func checkForUpdates() {
        checkForUpdatesCallCount += 1
        lastUpdateCheckDate = Date()
    }
}
