//
//  UpdateManager.swift
//  VibeCaption
//
//  Handles app update checks via Sparkle and persisted update preferences.
//

import Foundation
import os.log
import Combine

#if canImport(Sparkle)
import Sparkle
#endif

protocol AppUpdateDriverProtocol: AnyObject {
    var automaticallyChecksForUpdates: Bool { get set }
    var updateCheckInterval: TimeInterval { get set }
    var lastUpdateCheckDate: Date? { get }
    func checkForUpdates()
}

#if canImport(Sparkle)
private final class SparkleUpdateDriver: AppUpdateDriverProtocol {
    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var automaticallyChecksForUpdates: Bool {
        get { updaterController.updater.automaticallyChecksForUpdates }
        set { updaterController.updater.automaticallyChecksForUpdates = newValue }
    }

    var updateCheckInterval: TimeInterval {
        get { updaterController.updater.updateCheckInterval }
        set { updaterController.updater.updateCheckInterval = newValue }
    }

    var lastUpdateCheckDate: Date? {
        updaterController.updater.lastUpdateCheckDate
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
#else
private final class SparkleUpdateDriver: AppUpdateDriverProtocol {
    var automaticallyChecksForUpdates: Bool = true
    var updateCheckInterval: TimeInterval = 60 * 60 * 24
    var lastUpdateCheckDate: Date?

    func checkForUpdates() {
        lastUpdateCheckDate = Date()
    }
}
#endif

public final class UpdateManager: ObservableObject {

    // MARK: - Published State

    @Published private(set) var automaticallyChecksForUpdates: Bool
    @Published private(set) var appUpdateCheckIntervalHours: Int
    @Published private(set) var lastCheckedAt: Date?
    @Published private(set) var currentVersion: String
    @Published private(set) var currentBuild: String
    @Published private(set) var isCheckingForUpdates: Bool = false

    // MARK: - Dependencies

    private let settingsManager: SettingsManager
    private let updateDriver: AppUpdateDriverProtocol
    private let now: () -> Date
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.vibecaption",
        category: "UpdateManager"
    )

    // MARK: - Init

    init(
        settingsManager: SettingsManager,
        updateDriver: AppUpdateDriverProtocol? = nil,
        bundle: Bundle = .main,
        now: @escaping () -> Date = Date.init
    ) {
        self.settingsManager = settingsManager
        self.updateDriver = updateDriver ?? SparkleUpdateDriver()
        self.now = now

        currentVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        currentBuild = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        automaticallyChecksForUpdates = settingsManager.autoAppUpdatesEnabled
        appUpdateCheckIntervalHours = settingsManager.appUpdateCheckIntervalHours
        lastCheckedAt = settingsManager.appLastUpdateCheckDate

        configureUpdaterFromSettings()
        refreshLastCheckedDate()
    }

    // MARK: - Public API

    func configureUpdaterFromSettings() {
        updateDriver.automaticallyChecksForUpdates = settingsManager.autoAppUpdatesEnabled
        updateDriver.updateCheckInterval = TimeInterval(settingsManager.appUpdateCheckIntervalHours) * 3600
        automaticallyChecksForUpdates = settingsManager.autoAppUpdatesEnabled
        appUpdateCheckIntervalHours = settingsManager.appUpdateCheckIntervalHours
    }

    func setAutomaticAppUpdatesEnabled(_ enabled: Bool) {
        settingsManager.autoAppUpdatesEnabled = enabled
        updateDriver.automaticallyChecksForUpdates = enabled
        automaticallyChecksForUpdates = enabled
        logger.info("Automatic app updates enabled: \(enabled)")
    }

    func setAppUpdateCheckInterval(hours: Int) {
        let safeHours = max(1, min(hours, 24 * 14))
        settingsManager.appUpdateCheckIntervalHours = safeHours
        updateDriver.updateCheckInterval = TimeInterval(safeHours) * 3600
        appUpdateCheckIntervalHours = safeHours
        logger.info("App update check interval set to \(safeHours) hours")
    }

    func checkForAppUpdates() {
        isCheckingForUpdates = true
        updateDriver.checkForUpdates()

        let checkedAt = now()
        settingsManager.appLastUpdateCheckDate = checkedAt
        lastCheckedAt = checkedAt
        isCheckingForUpdates = false
        logger.info("Manual app update check triggered")
    }

    func refreshLastCheckedDate() {
        if let driverDate = updateDriver.lastUpdateCheckDate {
            lastCheckedAt = driverDate
            settingsManager.appLastUpdateCheckDate = driverDate
        } else {
            lastCheckedAt = settingsManager.appLastUpdateCheckDate
        }
    }
}
