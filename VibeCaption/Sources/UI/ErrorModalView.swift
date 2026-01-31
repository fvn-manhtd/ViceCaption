//
//  ErrorModalView.swift
//  VibeCaption
//
//  SwiftUI modal view for displaying errors with recovery actions.
//

import SwiftUI

// MARK: - ErrorModalView

/// Modal view for displaying errors with recovery options.
///
/// Displays:
/// - Error icon
/// - Error description
/// - Recovery suggestion
/// - "Fix Now" button (if recovery action available)
/// - "Dismiss" button
///
/// Example:
/// ```swift
/// .sheet(isPresented: $errorHandler.showErrorModal) {
///     if let error = errorHandler.currentError {
///         ErrorModalView(error: error)
///     }
/// }
/// ```
public struct ErrorModalView: View {
    
    // MARK: - Properties
    
    /// The error to display.
    private let error: VibeCaptionError
    
    /// Action to dismiss the modal.
    private let onDismiss: () -> Void
    
    /// Action to execute recovery.
    private let onRecovery: () -> Void
    
    // MARK: - Initialization
    
    /// Creates an error modal view.
    ///
    /// - Parameters:
    ///   - error: The error to display.
    ///   - onDismiss: Closure called when dismiss is tapped.
    ///   - onRecovery: Closure called when recovery action is tapped.
    public init(
        error: VibeCaptionError,
        onDismiss: @escaping () -> Void,
        onRecovery: @escaping () -> Void
    ) {
        self.error = error
        self.onDismiss = onDismiss
        self.onRecovery = onRecovery
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: 20) {
            // Error Icon
            Image(systemName: errorIcon)
                .font(.system(size: 48))
                .foregroundStyle(iconColor)
            
            // Error Title
            Text("Error")
                .font(.headline)
            
            // Error Description
            Text(error.localizedDescription)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
            
            // Recovery Suggestion
            Text(error.recoverySuggestion)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            Divider()
            
            // Action Buttons
            HStack(spacing: 16) {
                // Dismiss Button
                Button(action: onDismiss) {
                    Text("Dismiss")
                        .frame(minWidth: 80)
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                // Recovery Button (if available)
                if error.recoveryAction.hasRecoveryButton {
                    Button(action: onRecovery) {
                        Text(error.recoveryAction.buttonTitle)
                            .frame(minWidth: 80)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [])
                }
            }
        }
        .padding(24)
        .frame(minWidth: 360, maxWidth: 420)
    }
    
    // MARK: - Computed Properties
    
    /// Icon name based on error type.
    private var errorIcon: String {
        switch error {
        case .audioRoutingFailed, .noAudioFramesDetected, .blackHoleNotInstalled, .inputDeviceMismatch, .feedbackLoopDetected:
            return "speaker.slash.fill"
        case .modelMissing, .modelCorrupted, .modelDownloadFailed, .coreMLLoadFailed:
            return "cpu.fill"
        case .translationFailed, .asrFailed:
            return "text.bubble.fill"
        case .outOfMemory:
            return "memorychip.fill"
        }
    }
    
    /// Icon color based on error severity.
    private var iconColor: Color {
        switch error {
        case .outOfMemory:
            return .red
        case .blackHoleNotInstalled, .modelMissing:
            return .orange
        default:
            return .yellow
        }
    }
}

// MARK: - ErrorModalView with ErrorHandler

/// Convenience view that uses ErrorHandler directly.
public struct ErrorModalContainer: View {
    
    @ObservedObject private var errorHandler: ErrorHandler
    
    public init(errorHandler: ErrorHandler = ErrorHandler.shared) {
        self.errorHandler = errorHandler
    }
    
    public var body: some View {
        Group {
            if let error = errorHandler.currentError {
                ErrorModalView(
                    error: error,
                    onDismiss: { errorHandler.dismissError() },
                    onRecovery: { errorHandler.executeRecoveryAction() }
                )
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Audio Error") {
    ErrorModalView(
        error: .audioRoutingFailed(device: "BlackHole 2ch", reason: "Device not available"),
        onDismiss: {},
        onRecovery: {}
    )
}

#Preview("Model Error") {
    ErrorModalView(
        error: .modelMissing(modelName: "VibeVoice-ASR"),
        onDismiss: {},
        onRecovery: {}
    )
}

#Preview("Out of Memory") {
    ErrorModalView(
        error: .outOfMemory,
        onDismiss: {},
        onRecovery: {}
    )
}
#endif
