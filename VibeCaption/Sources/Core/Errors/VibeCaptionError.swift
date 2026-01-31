//
//  VibeCaptionError.swift
//  VibeCaption
//
//  Defines all error types for the VibeCaption application.
//

import Foundation

// MARK: - VibeCaptionError

/// Errors that can occur within the VibeCaption application.
///
/// Each error case includes associated values for context and
/// provides computed properties for user-facing messages and recovery actions.
///
/// Example:
/// ```swift
/// let error = VibeCaptionError.modelMissing(modelName: "VibeVoice-ASR")
/// print(error.localizedDescription)
/// print(error.recoverySuggestion)
/// ```
public enum VibeCaptionError: Error, Equatable, Sendable {
    
    // MARK: - Audio Errors
    
    /// Audio routing failed for a specific device.
    case audioRoutingFailed(device: String, reason: String)
    
    /// No audio frames were detected from the input.
    case noAudioFramesDetected
    
    /// BlackHole audio driver is not installed.
    case blackHoleNotInstalled
    
    /// Input device doesn't match expected configuration.
    case inputDeviceMismatch(expected: String, actual: String)
    
    /// Audio feedback loop detected (same device for input and output).
    case feedbackLoopDetected(inputDevice: String, outputDevice: String)
    
    // MARK: - Model Errors
    
    /// Required ML model is not found.
    case modelMissing(modelName: String)
    
    /// ML model file is corrupted.
    case modelCorrupted(modelName: String, path: String)
    
    /// Failed to download ML model.
    case modelDownloadFailed(modelName: String, reason: String)
    
    /// Failed to load CoreML model.
    case coreMLLoadFailed(modelName: String, reason: String)
    
    // MARK: - Processing Errors
    
    /// Translation processing failed.
    case translationFailed(reason: String)
    
    /// Automatic speech recognition failed.
    case asrFailed(reason: String)
    
    /// System ran out of memory.
    case outOfMemory
}

// MARK: - LocalizedError Conformance

extension VibeCaptionError: LocalizedError {
    
    /// User-facing localized description of the error.
    public var errorDescription: String? {
        localizedDescription
    }
}

// MARK: - Error Properties

extension VibeCaptionError {
    
    /// User-facing description of the error.
    public var localizedDescription: String {
        switch self {
        case .audioRoutingFailed(let device, let reason):
            return "Audio routing failed for \"\(device)\": \(reason)"
            
        case .noAudioFramesDetected:
            return "No audio input detected"
            
        case .blackHoleNotInstalled:
            return "BlackHole audio driver is not installed"
            
        case .inputDeviceMismatch(let expected, let actual):
            return "Audio input device mismatch: expected \"\(expected)\" but found \"\(actual)\""
            
        case .feedbackLoopDetected(let inputDevice, let outputDevice):
            return "Audio feedback loop detected: \"\(inputDevice)\" cannot be used for both input and output"
            
        case .modelMissing(let modelName):
            return "Model \"\(modelName)\" is not installed"
            
        case .modelCorrupted(let modelName, _):
            return "Model \"\(modelName)\" is corrupted"
            
        case .modelDownloadFailed(let modelName, let reason):
            return "Failed to download model \"\(modelName)\": \(reason)"
            
        case .coreMLLoadFailed(let modelName, let reason):
            return "Failed to load model \"\(modelName)\": \(reason)"
            
        case .translationFailed(let reason):
            return "Translation failed: \(reason)"
            
        case .asrFailed(let reason):
            return "Speech recognition failed: \(reason)"
            
        case .outOfMemory:
            return "System ran out of memory"
        }
    }
    
    /// Actionable suggestion for how to resolve the error.
    public var recoverySuggestion: String {
        switch self {
        case .audioRoutingFailed:
            return "Check your audio settings and ensure the device is properly connected. Run the setup wizard to reconfigure audio routing."
            
        case .noAudioFramesDetected:
            return "Make sure audio is playing and the correct input device is selected. Check system sound settings."
            
        case .blackHoleNotInstalled:
            return "BlackHole is required to capture system audio. Install it from the official website and run the setup wizard."
            
        case .inputDeviceMismatch:
            return "The configured audio device has changed. Run the setup wizard to select the correct device."
            
        case .feedbackLoopDetected:
            return "Select a different output device for monitoring to prevent audio feedback."
            
        case .modelMissing:
            return "The required AI model needs to be downloaded. Open model management to download it."
            
        case .modelCorrupted(_, let path):
            return "The model file at \"\(path)\" is corrupted. Delete and re-download the model from model management."
            
        case .modelDownloadFailed:
            return "Check your internet connection and try downloading the model again."
            
        case .coreMLLoadFailed:
            return "Try restarting the application. If the problem persists, re-download the model."
            
        case .translationFailed:
            return "Try again. If the problem persists, check the diagnostics panel for more information."
            
        case .asrFailed:
            return "Try again. If the problem persists, check the diagnostics panel for more information."
            
        case .outOfMemory:
            return "Close other applications to free up memory. Consider enabling performance mode in settings."
        }
    }
    
    /// The recommended recovery action for this error.
    public var recoveryAction: RecoveryAction {
        switch self {
        case .audioRoutingFailed, .inputDeviceMismatch, .blackHoleNotInstalled, .feedbackLoopDetected:
            return .openSetupWizard
            
        case .noAudioFramesDetected:
            return .openDiagnostics
            
        case .modelMissing, .modelCorrupted, .modelDownloadFailed:
            return .openModelManagement
            
        case .coreMLLoadFailed:
            return .retry
            
        case .translationFailed, .asrFailed:
            return .retry
            
        case .outOfMemory:
            return .none
        }
    }
}
