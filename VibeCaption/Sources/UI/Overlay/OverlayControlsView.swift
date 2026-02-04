//
//  OverlayControlsView.swift
//  VibeCaption
//
//  Top-left controls for overlay status and pause/resume actions.
//

import SwiftUI

struct OverlayControlsView: View {
    @ObservedObject var appStateManager: AppStateManager
    let showKeypressFeedback: Bool
    let onPause: () -> Void
    let onResume: () -> Void
    
    var body: some View {
        let state = appStateManager.currentState
        
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                StatusDotView(state: state)
                
                if Self.shouldShowPauseButton(for: state) {
                    Button(action: onPause) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .help("Pause")
                }
                
                if Self.shouldShowResumeButton(for: state) {
                    Button(action: onResume) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .help("Resume")
                }
            }
            
            if Self.shouldShowPausedLabel(for: state) {
                Text("Paused")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if Self.shouldShowIdleHint(for: state) {
                Text("Press Space to translate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.25))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(showKeypressFeedback ? Color.accentColor.opacity(0.9) : .clear, lineWidth: 1.5)
        )
        .animation(.easeInOut(duration: 0.15), value: showKeypressFeedback)
    }
}

extension OverlayControlsView {
    static func shouldShowPauseButton(for state: AppState) -> Bool {
        state == .listening || state == .translating
    }
    
    static func shouldShowResumeButton(for state: AppState) -> Bool {
        state == .paused
    }
    
    static func shouldShowPausedLabel(for state: AppState) -> Bool {
        state == .paused
    }
    
    static func shouldShowIdleHint(for state: AppState) -> Bool {
        state == .idle
    }
}
