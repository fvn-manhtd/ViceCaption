//
//  SettingsManager.swift
//  VibeCaption
//
//  Manages persistence of user settings using UserDefaults.
//

import Foundation
import Combine
import os.log

// MARK: - SettingsManager

/// Manages the persistence and retrieval of user settings.
///
/// This class provides a centralized interface for reading and writing
/// application settings, with automatic persistence to UserDefaults.
///
/// Usage:
/// ```swift
/// let manager = SettingsManager()
/// manager.overlayFontSize = .large
/// print(manager.overlayFontSize) // .large
/// ```
public final class SettingsManager: ObservableObject {
    
    // MARK: - UserDefaults Keys
    
    private enum Keys {
        static let audioInputDeviceID = "audioInputDeviceID"
        static let monitoringOutputDeviceID = "monitoringOutputDeviceID"
        static let noiseSuppressionEnabled = "noiseSuppressionEnabled"
        static let overlayFontSize = "overlayFontSize"
        static let overlayMaxWidth = "overlayMaxWidth"
        static let overlayAutoHideSeconds = "overlayAutoHideSeconds"
        static let performanceModeEnabled = "performanceModeEnabled"
        static let modelStoragePath = "modelStoragePath"
        static let transcriptStoragePath = "transcriptStoragePath"
    }
    
    // MARK: - Properties
    
    private let userDefaults: UserDefaults
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.yourcompany.vibecaption",
        category: "SettingsManager"
    )
    
    /// Publisher for settings changes - triggers SwiftUI updates.
    @Published private var settingsDidChange: Bool = false
    
    // MARK: - Initialization
    
    /// Creates a SettingsManager with the specified UserDefaults.
    ///
    /// - Parameter userDefaults: The UserDefaults instance to use.
    ///   Pass a custom instance for testing purposes.
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        logger.debug("SettingsManager initialized")
        validatePaths()
    }
    
    // MARK: - Audio Settings
    
    /// The audio input device ID for capture. `nil` uses system default.
    public var audioInputDeviceID: String? {
        get {
            userDefaults.string(forKey: Keys.audioInputDeviceID)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.audioInputDeviceID)
            notifyChange()
            logger.debug("Audio input device ID set to: \(newValue ?? "default")")
        }
    }
    
    /// The audio output device ID for monitoring. `nil` uses system default.
    public var monitoringOutputDeviceID: String? {
        get {
            userDefaults.string(forKey: Keys.monitoringOutputDeviceID)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.monitoringOutputDeviceID)
            notifyChange()
            logger.debug("Monitoring output device ID set to: \(newValue ?? "default")")
        }
    }
    
    /// Whether noise suppression is enabled during capture.
    public var noiseSuppressionEnabled: Bool {
        get {
            if userDefaults.object(forKey: Keys.noiseSuppressionEnabled) == nil {
                return AppSettings.defaultNoiseSuppressionEnabled
            }
            return userDefaults.bool(forKey: Keys.noiseSuppressionEnabled)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.noiseSuppressionEnabled)
            notifyChange()
            logger.debug("Noise suppression enabled: \(newValue)")
        }
    }
    
    // MARK: - Overlay Settings
    
    /// Font size for the overlay caption display.
    public var overlayFontSize: FontSize {
        get {
            guard let rawValue = userDefaults.string(forKey: Keys.overlayFontSize),
                  let fontSize = FontSize(rawValue: rawValue) else {
                return AppSettings.defaultOverlayFontSize
            }
            return fontSize
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: Keys.overlayFontSize)
            notifyChange()
            logger.debug("Overlay font size set to: \(newValue.displayName)")
        }
    }
    
    /// Maximum width of the overlay window in points.
    public var overlayMaxWidth: CGFloat {
        get {
            let value = userDefaults.double(forKey: Keys.overlayMaxWidth)
            return value > 0 ? CGFloat(value) : AppSettings.defaultOverlayMaxWidth
        }
        set {
            userDefaults.set(Double(newValue), forKey: Keys.overlayMaxWidth)
            notifyChange()
            logger.debug("Overlay max width set to: \(newValue)")
        }
    }
    
    /// Seconds of inactivity before auto-hiding the overlay.
    public var overlayAutoHideSeconds: Int {
        get {
            let value = userDefaults.integer(forKey: Keys.overlayAutoHideSeconds)
            // Return default if never set (0 could be valid but we check if key exists)
            if userDefaults.object(forKey: Keys.overlayAutoHideSeconds) == nil {
                return AppSettings.defaultOverlayAutoHideSeconds
            }
            return value
        }
        set {
            userDefaults.set(newValue, forKey: Keys.overlayAutoHideSeconds)
            notifyChange()
            logger.debug("Overlay auto-hide seconds set to: \(newValue)")
        }
    }
    
    // MARK: - Performance Settings
    
    /// Whether performance mode is enabled.
    public var performanceModeEnabled: Bool {
        get {
            if userDefaults.object(forKey: Keys.performanceModeEnabled) == nil {
                return AppSettings.defaultPerformanceModeEnabled
            }
            return userDefaults.bool(forKey: Keys.performanceModeEnabled)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.performanceModeEnabled)
            notifyChange()
            logger.debug("Performance mode enabled: \(newValue)")
        }
    }
    
    // MARK: - Storage Paths
    
    /// Path where AI models are stored.
    public var modelStoragePath: String {
        get {
            userDefaults.string(forKey: Keys.modelStoragePath) ?? AppSettings.defaultModelStoragePath
        }
        set {
            userDefaults.set(newValue, forKey: Keys.modelStoragePath)
            notifyChange()
            validatePath(newValue)
            logger.debug("Model storage path set to: \(newValue)")
        }
    }
    
    /// Path where transcripts are saved.
    public var transcriptStoragePath: String {
        get {
            userDefaults.string(forKey: Keys.transcriptStoragePath) ?? AppSettings.defaultTranscriptStoragePath
        }
        set {
            userDefaults.set(newValue, forKey: Keys.transcriptStoragePath)
            notifyChange()
            validatePath(newValue)
            logger.debug("Transcript storage path set to: \(newValue)")
        }
    }
    
    // MARK: - Convenience Accessors
    
    /// Returns all current settings as an AppSettings instance.
    public var currentSettings: AppSettings {
        AppSettings(
            audioInputDeviceID: audioInputDeviceID,
            monitoringOutputDeviceID: monitoringOutputDeviceID,
            noiseSuppressionEnabled: noiseSuppressionEnabled,
            overlayFontSize: overlayFontSize,
            overlayMaxWidth: overlayMaxWidth,
            overlayAutoHideSeconds: overlayAutoHideSeconds,
            performanceModeEnabled: performanceModeEnabled,
            modelStoragePath: modelStoragePath,
            transcriptStoragePath: transcriptStoragePath
        )
    }
    
    // MARK: - Reset
    
    /// Resets all settings to their default values.
    public func resetToDefaults() {
        logger.info("Resetting all settings to defaults")
        
        userDefaults.removeObject(forKey: Keys.audioInputDeviceID)
        userDefaults.removeObject(forKey: Keys.monitoringOutputDeviceID)
        userDefaults.removeObject(forKey: Keys.noiseSuppressionEnabled)
        userDefaults.removeObject(forKey: Keys.overlayFontSize)
        userDefaults.removeObject(forKey: Keys.overlayMaxWidth)
        userDefaults.removeObject(forKey: Keys.overlayAutoHideSeconds)
        userDefaults.removeObject(forKey: Keys.performanceModeEnabled)
        userDefaults.removeObject(forKey: Keys.modelStoragePath)
        userDefaults.removeObject(forKey: Keys.transcriptStoragePath)
        
        notifyChange()
        validatePaths()
    }
    
    // MARK: - Path Validation
    
    /// Validates and creates storage directories if they don't exist.
    public func validatePaths() {
        validatePath(modelStoragePath)
        validatePath(transcriptStoragePath)
    }
    
    /// Validates a single path, creating the directory if it doesn't exist.
    ///
    /// - Parameter path: The directory path to validate.
    @discardableResult
    public func validatePath(_ path: String) -> Bool {
        let fileManager = FileManager.default
        let expandedPath = (path as NSString).expandingTildeInPath
        
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                logger.debug("Path exists: \(expandedPath)")
                return true
            } else {
                logger.warning("Path exists but is not a directory: \(expandedPath)")
                return false
            }
        }
        
        do {
            try fileManager.createDirectory(
                atPath: expandedPath,
                withIntermediateDirectories: true,
                attributes: nil
            )
            logger.info("Created directory: \(expandedPath)")
            return true
        } catch {
            logger.error("Failed to create directory: \(expandedPath), error: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Private Methods
    
    /// Notifies observers that settings have changed.
    private func notifyChange() {
        settingsDidChange.toggle()
    }
}
