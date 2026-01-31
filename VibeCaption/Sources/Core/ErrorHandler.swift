//
//  ErrorHandler.swift
//  VibeCaption
//
//  Centralized error handling with logging and UI binding.
//

import Foundation
import Combine
import OSLog

// MARK: - ErrorHandlerDelegate

/// Delegate protocol for executing recovery actions.
public protocol ErrorHandlerDelegate: AnyObject {
    /// Called when the user requests a recovery action.
    ///
    /// - Parameter action: The recovery action to execute.
    func executeRecoveryAction(_ action: RecoveryAction)
}

// MARK: - ErrorLogEntry

/// A logged error entry with timestamp.
public struct ErrorLogEntry: Identifiable, Sendable {
    public let id: UUID
    public let error: VibeCaptionError
    public let timestamp: Date
    
    public init(error: VibeCaptionError, timestamp: Date = Date()) {
        self.id = UUID()
        self.error = error
        self.timestamp = timestamp
    }
}

// MARK: - ErrorHandler

/// Centralized singleton for app-wide error handling.
///
/// ErrorHandler provides:
/// - Published property for SwiftUI binding
/// - Delegate pattern for recovery action execution
/// - Logging of all errors with timestamps
///
/// Example:
/// ```swift
/// ErrorHandler.shared.handleError(.modelMissing(modelName: "ASR"))
/// ```
@MainActor
public final class ErrorHandler: ObservableObject {
    
    // MARK: - Singleton
    
    /// Shared singleton instance.
    public static let shared = ErrorHandler()
    
    // MARK: - Published Properties
    
    /// The current error to display in the UI (nil means no active error).
    @Published public private(set) var currentError: VibeCaptionError?
    
    /// Whether the error modal should be shown.
    @Published public var showErrorModal: Bool = false
    
    // MARK: - Properties
    
    /// Delegate for executing recovery actions.
    public weak var delegate: ErrorHandlerDelegate?
    
    /// In-memory log of all errors (limit to prevent memory bloat).
    public private(set) var errorLog: [ErrorLogEntry] = []
    
    /// Maximum number of errors to keep in memory.
    private let maxLogEntries: Int = 100
    
    /// Logger for error events.
    private let logger = Logger(subsystem: "com.vibecaption", category: "ErrorHandler")
    
    // MARK: - Initialization
    
    /// Creates a new error handler.
    /// Use `ErrorHandler.shared` for the singleton instance.
    public init() {}
    
    // MARK: - Public Methods
    
    /// Handles an error by logging it and updating the UI state.
    ///
    /// - Parameter error: The error to handle.
    public func handleError(_ error: VibeCaptionError) {
        // Log to system
        logger.error("\(error.localizedDescription, privacy: .public)")
        
        // Add to in-memory log
        let entry = ErrorLogEntry(error: error)
        errorLog.append(entry)
        
        // Trim log if needed
        if errorLog.count > maxLogEntries {
            errorLog.removeFirst(errorLog.count - maxLogEntries)
        }
        
        // Update UI state
        currentError = error
        showErrorModal = true
    }
    
    /// Dismisses the current error modal.
    public func dismissError() {
        currentError = nil
        showErrorModal = false
    }
    
    /// Triggers the recovery action for the current error.
    public func executeRecoveryAction() {
        guard let error = currentError else { return }
        let action = error.recoveryAction
        
        logger.info("Executing recovery action: \(action.rawValue, privacy: .public)")
        
        dismissError()
        delegate?.executeRecoveryAction(action)
    }
    
    /// Clears all logged errors.
    public func clearErrorLog() {
        errorLog.removeAll()
    }
    
    /// Returns the most recent errors.
    ///
    /// - Parameter count: Maximum number of entries to return.
    /// - Returns: Array of recent error log entries.
    public func recentErrors(count: Int = 10) -> [ErrorLogEntry] {
        Array(errorLog.suffix(count))
    }
}
