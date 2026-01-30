//
//  AppState.swift
//  VibeCaption
//
//  Defines the application state machine states for VibeCaption.
//

import Foundation

/// Represents the current operational state of the VibeCaption application.
///
/// The app transitions between these states based on user actions and processing events.
/// State transitions are managed by `AppStateManager` which validates all transitions.
public enum AppState: Equatable, Hashable, CaseIterable {
    /// Default state - no audio processing is occurring.
    /// The app is idle and waiting for user action to begin listening.
    case idle
    
    /// Actively capturing and processing audio.
    /// Audio is being pulled from the input device and sent through the ASR pipeline.
    case listening
    
    /// Post-ASR translation is in progress.
    /// Audio capture continues but a translation task is actively running.
    case translating
    
    /// Temporarily stopped - no audio capture.
    /// User has paused the session but can resume without losing context.
    case paused
    
    // MARK: - Display Properties
    
    /// Human-readable name for the state, suitable for UI display.
    public var displayName: String {
        switch self {
        case .idle:
            return "Idle"
        case .listening:
            return "Listening"
        case .translating:
            return "Translating"
        case .paused:
            return "Paused"
        }
    }
    
    /// Short description of what the state means.
    public var description: String {
        switch self {
        case .idle:
            return "Ready to start capturing audio"
        case .listening:
            return "Capturing and processing audio"
        case .translating:
            return "Translation in progress"
        case .paused:
            return "Capture paused"
        }
    }
    
    // MARK: - State Query Properties
    
    /// Whether audio capture is active in this state.
    public var isCapturing: Bool {
        switch self {
        case .listening, .translating:
            return true
        case .idle, .paused:
            return false
        }
    }
    
    /// Whether processing (ASR or translation) is active.
    public var isProcessing: Bool {
        switch self {
        case .listening, .translating:
            return true
        case .idle, .paused:
            return false
        }
    }
    
    /// Whether the app can transition to listening state.
    public var canStartListening: Bool {
        switch self {
        case .idle, .paused:
            return true
        case .listening, .translating:
            return false
        }
    }
    
    /// Whether the app can be paused from this state.
    public var canPause: Bool {
        switch self {
        case .listening, .translating:
            return true
        case .idle, .paused:
            return false
        }
    }
}
