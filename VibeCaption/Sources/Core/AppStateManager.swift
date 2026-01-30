//
//  AppStateManager.swift
//  VibeCaption
//
//  Manages application state transitions with validation and notifications.
//

import Foundation
import Combine
import os.log

// MARK: - Error Types

/// Errors that can occur during state transitions.
public enum StateTransitionError: Error, Equatable {
    /// Attempted to start listening but models are not loaded.
    case modelsNotLoaded
    
    /// Attempted an invalid state transition.
    case invalidTransition(from: AppState, to: AppState)
    
    /// Attempted to resume but not in paused state.
    case notPaused
    
    /// Attempted to pause but not in a pausable state.
    case notPausable
}

extension StateTransitionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .modelsNotLoaded:
            return "Cannot start listening: AI models are not loaded"
        case .invalidTransition(let from, let to):
            return "Invalid state transition from \(from.displayName) to \(to.displayName)"
        case .notPaused:
            return "Cannot resume: not currently paused"
        case .notPausable:
            return "Cannot pause: not currently listening or translating"
        }
    }
}

// MARK: - State Change Callback

/// Signature for state change callbacks.
public typealias StateChangeCallback = (AppState, AppState) -> Void

// MARK: - AppStateManager

/// Manages the application state machine for VibeCaption.
///
/// This class is the single source of truth for the application's operational state.
/// It validates all state transitions and notifies observers of changes.
///
/// Usage:
/// ```swift
/// let manager = AppStateManager()
/// manager.onStateChange = { oldState, newState in
///     print("State changed from \(oldState) to \(newState)")
/// }
/// try manager.startListening()
/// ```
public final class AppStateManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The current operational state of the application.
    @Published public private(set) var currentState: AppState = .idle
    
    /// Whether the overlay window is currently visible.
    /// This is tracked separately to preserve state when hiding/showing the overlay.
    @Published public var isOverlayVisible: Bool = false
    
    // MARK: - Properties
    
    /// Whether the required AI models are loaded and ready.
    /// Must be true before `startListening()` can succeed.
    public var areModelsLoaded: Bool = false
    
    /// Callback invoked whenever the state changes.
    /// Parameters are (oldState, newState).
    public var onStateChange: StateChangeCallback?
    
    /// The state that was active before the overlay was hidden.
    /// Used to restore state when overlay is shown again.
    private var stateBeforeHidingOverlay: AppState?
    
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.yourcompany.vibecaption",
        category: "AppStateManager"
    )
    
    // MARK: - Initialization
    
    public init() {
        logger.debug("AppStateManager initialized with state: \(self.currentState.displayName)")
    }
    
    // MARK: - State Transition Methods
    
    /// Starts audio capture and processing.
    ///
    /// - Throws: `StateTransitionError.modelsNotLoaded` if AI models aren't ready.
    /// - Throws: `StateTransitionError.invalidTransition` if already listening/translating.
    public func startListening() throws {
        guard areModelsLoaded else {
            logger.warning("Cannot start listening: models not loaded")
            throw StateTransitionError.modelsNotLoaded
        }
        
        guard currentState.canStartListening else {
            logger.warning("Cannot start listening from state: \(self.currentState.displayName)")
            throw StateTransitionError.invalidTransition(from: currentState, to: .listening)
        }
        
        transition(to: .listening)
    }
    
    /// Stops audio capture and returns to idle state.
    ///
    /// This is a safe operation that can be called from any state.
    public func stopListening() {
        if currentState != .idle {
            transition(to: .idle)
        }
    }
    
    /// Pauses audio capture and processing.
    ///
    /// - Throws: `StateTransitionError.notPausable` if not in a pausable state.
    public func pause() throws {
        guard currentState.canPause else {
            logger.warning("Cannot pause from state: \(self.currentState.displayName)")
            throw StateTransitionError.notPausable
        }
        
        transition(to: .paused)
    }
    
    /// Resumes audio capture from paused state.
    ///
    /// - Throws: `StateTransitionError.notPaused` if not currently paused.
    public func resume() throws {
        guard currentState == .paused else {
            logger.warning("Cannot resume from state: \(self.currentState.displayName)")
            throw StateTransitionError.notPaused
        }
        
        transition(to: .listening)
    }
    
    /// Toggles the listening state - main handler for Space key.
    ///
    /// Behavior from each state:
    /// - `.idle`: Starts listening (if models loaded)
    /// - `.listening`: Pauses
    /// - `.translating`: Pauses
    /// - `.paused`: Resumes listening
    ///
    /// - Throws: `StateTransitionError.modelsNotLoaded` if toggling from idle without models.
    public func toggleListening() throws {
        switch currentState {
        case .idle:
            try startListening()
        case .listening, .translating:
            try pause()
        case .paused:
            try resume()
        }
    }
    
    // MARK: - Translation State
    
    /// Transitions to translating state when translation begins.
    ///
    /// This should be called by the translation service when starting a translation.
    /// Only valid when currently listening.
    public func beginTranslation() throws {
        guard currentState == .listening else {
            throw StateTransitionError.invalidTransition(from: currentState, to: .translating)
        }
        
        transition(to: .translating)
    }
    
    /// Transitions back to listening when translation completes.
    ///
    /// Only valid when currently translating.
    public func endTranslation() throws {
        guard currentState == .translating else {
            throw StateTransitionError.invalidTransition(from: currentState, to: .listening)
        }
        
        transition(to: .listening)
    }
    
    // MARK: - Overlay Visibility
    
    /// Notifies the manager that the overlay is being hidden.
    ///
    /// The current state is preserved so it can be restored when shown again.
    public func overlayWillHide() {
        stateBeforeHidingOverlay = currentState
        isOverlayVisible = false
        logger.debug("Overlay hiding, preserving state: \(self.currentState.displayName)")
    }
    
    /// Notifies the manager that the overlay is being shown.
    ///
    /// If there was a preserved state, it can be restored.
    public func overlayWillShow() {
        isOverlayVisible = true
        logger.debug("Overlay showing, preserved state was: \(self.stateBeforeHidingOverlay?.displayName ?? "none")")
    }
    
    /// Returns the state that was active before the overlay was hidden, if any.
    public var preservedState: AppState? {
        return stateBeforeHidingOverlay
    }
    
    // MARK: - Private Methods
    
    /// Performs the actual state transition and notifies observers.
    private func transition(to newState: AppState) {
        let oldState = currentState
        currentState = newState
        
        logger.info("State transition: \(oldState.displayName) → \(newState.displayName)")
        
        onStateChange?(oldState, newState)
    }
}
