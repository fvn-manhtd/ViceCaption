//
//  ClearCaptionsPopup.swift
//  VibeCaption
//
//  Floating popup for clear captions options.
//

import SwiftUI

/// A floating popup that presents clear caption options.
///
/// Shows two action buttons:
/// - "Clear display only": Clears UI but preserves data for session file
/// - "Clear + discard": Permanently removes the data
///
/// Dismisses when clicking outside or pressing Escape.
struct ClearCaptionsPopup: View {
    /// Callback for "Clear display only" action.
    let onClearDisplayOnly: () -> Void
    
    /// Callback for "Clear + discard" action.
    let onClearAndDiscard: () -> Void
    
    /// Callback for dismissing the popup.
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Clear display only button
            Button(action: {
                onClearDisplayOnly()
            }) {
                HStack {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 14))
                    Text("Clear display only")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(ClearPopupButtonStyle())
            .help("Clear captions from display, but keep for saved file")
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            // Clear + discard button
            Button(action: {
                onClearAndDiscard()
            }) {
                HStack {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                    Text("Clear + discard")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(ClearPopupButtonStyle(isDestructive: true))
            .help("Clear captions and remove permanently")
        }
        .frame(width: 180)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
        .onExitCommand {
            onDismiss()
        }
    }
}

// MARK: - Button Style

/// Custom button style for popup actions.
private struct ClearPopupButtonStyle: ButtonStyle {
    var isDestructive: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isDestructive ? Color.red.opacity(0.9) : Color.white.opacity(0.9))
            .background(
                configuration.isPressed
                    ? Color.white.opacity(0.1)
                    : Color.clear
            )
    }
}

// MARK: - Popup Overlay Container

/// A container view that shows the popup with a dismissable backdrop.
struct ClearCaptionsPopupOverlay: View {
    @Binding var isPresented: Bool
    let anchorAlignment: Alignment
    let onClearDisplayOnly: () -> Void
    let onClearAndDiscard: () -> Void
    
    var body: some View {
        if isPresented {
            ZStack(alignment: anchorAlignment) {
                // Dismissal backdrop
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isPresented = false
                    }
                
                // Popup
                ClearCaptionsPopup(
                    onClearDisplayOnly: {
                        onClearDisplayOnly()
                        isPresented = false
                    },
                    onClearAndDiscard: {
                        onClearAndDiscard()
                        isPresented = false
                    },
                    onDismiss: {
                        isPresented = false
                    }
                )
                .padding(.top, 45)
                .padding(.leading, 8)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topLeading)))
            }
            .animation(.easeOut(duration: 0.15), value: isPresented)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ClearCaptionsPopup_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.3)
            ClearCaptionsPopup(
                onClearDisplayOnly: {},
                onClearAndDiscard: {},
                onDismiss: {}
            )
        }
        .frame(width: 300, height: 200)
    }
}
#endif
