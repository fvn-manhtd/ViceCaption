//
//  RecoveryAction.swift
//  VibeCaption
//
//  Defines recovery actions for error handling.
//

import Foundation

// MARK: - RecoveryAction

/// Actions that can be taken to recover from an error.
///
/// Each action corresponds to a specific UI flow or operation
/// that can help the user resolve the error condition.
public enum RecoveryAction: String, CaseIterable, Sendable {
    
    /// Open the setup wizard to fix audio routing issues.
    case openSetupWizard
    
    /// Open model management to download or repair models.
    case openModelManagement
    
    /// Open diagnostics panel for debugging.
    case openDiagnostics
    
    /// Retry the failed operation.
    case retry
    
    /// No recovery action available.
    case none
    
    // MARK: - Properties
    
    /// User-facing button title for the action.
    public var buttonTitle: String {
        switch self {
        case .openSetupWizard:
            return "Open Setup Wizard"
        case .openModelManagement:
            return "Manage Models"
        case .openDiagnostics:
            return "Open Diagnostics"
        case .retry:
            return "Retry"
        case .none:
            return ""
        }
    }
    
    /// Whether this action should show a "Fix Now" button.
    public var hasRecoveryButton: Bool {
        self != .none
    }
}
