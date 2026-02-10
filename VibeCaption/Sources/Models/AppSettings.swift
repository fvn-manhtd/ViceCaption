//
//  AppSettings.swift
//  VibeCaption
//
//  Models for user preferences and application settings.
//

import Foundation

// MARK: - ASREngineType Enum

/// The speech recognition engine to use for transcription.
public enum ASREngineType: String, CaseIterable, Codable {
    /// Apple's built-in Speech framework (SFSpeechRecognizer).
    /// Low latency, on-device, no model download required.
    case appleSpeech

    /// OpenAI Whisper via SwiftWhisper.
    /// Higher accuracy for specialized vocabulary, requires model download.
    case whisper

    public var displayName: String {
        switch self {
        case .appleSpeech: return "Apple Speech"
        case .whisper: return "Whisper"
        }
    }
}

// MARK: - FontSize Enum

/// Font size options for the overlay display.
public enum FontSize: String, CaseIterable, Codable {
    case small
    case medium
    case large
    
    /// Display name for UI presentation.
    public var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
    
    /// Actual font size in points.
    public var fontSize: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 14
        case .large: return 18
        }
    }
}

// MARK: - AppSettings

/// Model containing all user-configurable application settings.
///
/// This struct represents the complete set of preferences that can be
/// customized by the user and persisted between app launches.
public struct AppSettings: Equatable, Codable {
    
    // MARK: - Audio Settings
    
    /// The audio input device ID for capture. `nil` uses system default.
    public var audioInputDeviceID: String?
    
    /// The audio output device ID for monitoring. `nil` uses system default.
    public var monitoringOutputDeviceID: String?
    
    /// Whether noise suppression is enabled during capture.
    public var noiseSuppressionEnabled: Bool
    
    // MARK: - Overlay Settings
    
    /// Font size for the overlay caption display.
    public var overlayFontSize: FontSize
    
    /// Maximum width of the overlay window in points.
    public var overlayMaxWidth: CGFloat
    
    /// Seconds of inactivity before auto-hiding the overlay.
    public var overlayAutoHideSeconds: Int
    
    // MARK: - Performance Settings
    
    /// Whether performance mode is enabled (reduces quality for lower CPU usage).
    public var performanceModeEnabled: Bool
    
    // MARK: - Storage Paths
    
    /// Path where AI models are stored.
    public var modelStoragePath: String
    
    /// Path where transcripts are saved.
    public var transcriptStoragePath: String

    // MARK: - Update Settings

    /// Whether app update checks are enabled automatically.
    public var autoAppUpdatesEnabled: Bool

    /// App update check interval in hours.
    public var appUpdateCheckIntervalHours: Int

    /// Whether critical app updates should be enforced.
    public var enforceCriticalAppUpdates: Bool

    /// Optional remote model catalog URL used to discover model updates.
    public var modelCatalogURL: String?

    // MARK: - ASR Engine Settings

    /// The speech recognition engine to use.
    public var asrEngine: ASREngineType
    
    // MARK: - Default Values
    
    /// Default audio input device ID (nil = system default).
    public static let defaultAudioInputDeviceID: String? = nil
    
    /// Default monitoring output device ID (nil = system default).
    public static let defaultMonitoringOutputDeviceID: String? = nil
    
    /// Default noise suppression setting.
    public static let defaultNoiseSuppressionEnabled: Bool = true
    
    /// Default overlay font size.
    public static let defaultOverlayFontSize: FontSize = .medium
    
    /// Default overlay maximum width.
    public static let defaultOverlayMaxWidth: CGFloat = 480
    
    /// Default overlay auto-hide seconds.
    public static let defaultOverlayAutoHideSeconds: Int = 30
    
    /// Default performance mode setting.
    public static let defaultPerformanceModeEnabled: Bool = false
    
    /// Default model storage path.
    public static var defaultModelStoragePath: String {
        let documentsPath = NSSearchPathForDirectoriesInDomains(
            .documentDirectory,
            .userDomainMask,
            true
        ).first ?? "~/Documents"
        return (documentsPath as NSString).appendingPathComponent("VibeCaption/Models")
    }
    
    /// Default transcript storage path.
    public static var defaultTranscriptStoragePath: String {
        let documentsPath = NSSearchPathForDirectoriesInDomains(
            .documentDirectory,
            .userDomainMask,
            true
        ).first ?? "~/Documents"
        return (documentsPath as NSString).appendingPathComponent("VibeCaption/Transcripts")
    }

    /// Default automatic app updates setting.
    public static let defaultAutoAppUpdatesEnabled: Bool = true

    /// Default Sparkle app update check interval (hours).
    public static let defaultAppUpdateCheckIntervalHours: Int = 24

    /// Default policy for enforcing critical app updates.
    public static let defaultEnforceCriticalAppUpdates: Bool = false

    /// Default URL for remote model update catalog.
    public static let defaultModelCatalogURL: String? = nil

    /// Default ASR engine — Apple Speech for low-latency real-time transcription.
    public static let defaultASREngine: ASREngineType = .appleSpeech
    
    // MARK: - Initialization
    
    /// Creates settings with default values.
    public init() {
        self.audioInputDeviceID = Self.defaultAudioInputDeviceID
        self.monitoringOutputDeviceID = Self.defaultMonitoringOutputDeviceID
        self.noiseSuppressionEnabled = Self.defaultNoiseSuppressionEnabled
        self.overlayFontSize = Self.defaultOverlayFontSize
        self.overlayMaxWidth = Self.defaultOverlayMaxWidth
        self.overlayAutoHideSeconds = Self.defaultOverlayAutoHideSeconds
        self.performanceModeEnabled = Self.defaultPerformanceModeEnabled
        self.modelStoragePath = Self.defaultModelStoragePath
        self.transcriptStoragePath = Self.defaultTranscriptStoragePath
        self.autoAppUpdatesEnabled = Self.defaultAutoAppUpdatesEnabled
        self.appUpdateCheckIntervalHours = Self.defaultAppUpdateCheckIntervalHours
        self.enforceCriticalAppUpdates = Self.defaultEnforceCriticalAppUpdates
        self.modelCatalogURL = Self.defaultModelCatalogURL
        self.asrEngine = Self.defaultASREngine
    }
    
    /// Creates settings with custom values.
    public init(
        audioInputDeviceID: String? = defaultAudioInputDeviceID,
        monitoringOutputDeviceID: String? = defaultMonitoringOutputDeviceID,
        noiseSuppressionEnabled: Bool = defaultNoiseSuppressionEnabled,
        overlayFontSize: FontSize = defaultOverlayFontSize,
        overlayMaxWidth: CGFloat = defaultOverlayMaxWidth,
        overlayAutoHideSeconds: Int = defaultOverlayAutoHideSeconds,
        performanceModeEnabled: Bool = defaultPerformanceModeEnabled,
        modelStoragePath: String? = nil,
        transcriptStoragePath: String? = nil,
        autoAppUpdatesEnabled: Bool = defaultAutoAppUpdatesEnabled,
        appUpdateCheckIntervalHours: Int = defaultAppUpdateCheckIntervalHours,
        enforceCriticalAppUpdates: Bool = defaultEnforceCriticalAppUpdates,
        modelCatalogURL: String? = defaultModelCatalogURL,
        asrEngine: ASREngineType = defaultASREngine
    ) {
        self.audioInputDeviceID = audioInputDeviceID
        self.monitoringOutputDeviceID = monitoringOutputDeviceID
        self.noiseSuppressionEnabled = noiseSuppressionEnabled
        self.overlayFontSize = overlayFontSize
        self.overlayMaxWidth = overlayMaxWidth
        self.overlayAutoHideSeconds = overlayAutoHideSeconds
        self.performanceModeEnabled = performanceModeEnabled
        self.modelStoragePath = modelStoragePath ?? Self.defaultModelStoragePath
        self.transcriptStoragePath = transcriptStoragePath ?? Self.defaultTranscriptStoragePath
        self.autoAppUpdatesEnabled = autoAppUpdatesEnabled
        self.appUpdateCheckIntervalHours = appUpdateCheckIntervalHours
        self.enforceCriticalAppUpdates = enforceCriticalAppUpdates
        self.modelCatalogURL = modelCatalogURL
        self.asrEngine = asrEngine
    }
}
