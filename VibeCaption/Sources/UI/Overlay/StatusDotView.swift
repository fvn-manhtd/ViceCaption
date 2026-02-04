//
//  StatusDotView.swift
//  VibeCaption
//
//  Status indicator dot with tooltip and optional pulsing animation.
//

import SwiftUI

struct StatusDotView: View {
    let state: AppState
    @State private var isPulsing: Bool = false
    
    var body: some View {
        Circle()
            .fill(Self.color(for: state))
            .frame(width: 10, height: 10)
            .scaleEffect(isPulsing ? 1.35 : 1.0)
            .animation(pulseAnimation, value: isPulsing)
            .help(state.displayName)
            .onAppear {
                updatePulseState(for: state)
            }
            .onChange(of: state) { newState in
                updatePulseState(for: newState)
            }
    }
    
    private var pulseAnimation: Animation {
        state == .listening
            ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
            : .easeInOut(duration: 0.2)
    }
    
    private func updatePulseState(for state: AppState) {
        isPulsing = state == .listening
    }
}

extension StatusDotView {
    enum Style: String, Equatable {
        case idle
        case listening
        case translating
        case paused
        
        var color: Color {
            switch self {
            case .idle:
                return .gray
            case .listening:
                return .green
            case .translating:
                return .blue
            case .paused:
                return .yellow
            }
        }
    }
    
    static func style(for state: AppState) -> Style {
        switch state {
        case .idle:
            return .idle
        case .listening:
            return .listening
        case .translating:
            return .translating
        case .paused:
            return .paused
        }
    }
    
    static func color(for state: AppState) -> Color {
        style(for: state).color
    }
    
    static func shouldPulse(for state: AppState) -> Bool {
        state == .listening
    }
}
