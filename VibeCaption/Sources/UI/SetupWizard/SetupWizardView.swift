//
//  SetupWizardView.swift
//  VibeCaption
//
//  Main SwiftUI view for the Setup Wizard with step navigation.
//

import SwiftUI

/// Steps in the setup wizard process.
enum WizardStep: Int, CaseIterable, Identifiable {
    case welcome = 0
    case blackHoleCheck
    case audioRouting
    case audioTest
    case completion
    
    var id: Int { self.rawValue }
    
    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .blackHoleCheck: return "Components"
        case .audioRouting: return "Routing"
        case .audioTest: return "Test"
        case .completion: return "Finish"
        }
    }
}

/// Main wizard container view.
public struct SetupWizardView: View {
    
    // MARK: - Properties
    
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var audioDeviceManager: AudioDeviceManager
    
    var onClose: () -> Void
    var onComplete: () -> Void
    
    // MARK: - Local State
    
    @State private var currentStep: WizardStep = .welcome
    @State private var canProceed: Bool = true
    
    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header / Progress
            WizardProgressView(currentStep: currentStep)
                .padding(.vertical, 20)
                .background(Color(NSColor.controlBackgroundColor))
                .overlay(alignment: .bottom) {
                    Divider()
                }
            
            // Content
            ScrollView {
                VStack {
                    switch currentStep {
                    case .welcome:
                        WelcomeStepView()
                            .onAppear { canProceed = true }
                        
                    case .blackHoleCheck:
                        BlackHoleCheckStepView(
                            audioDeviceManager: audioDeviceManager,
                            canProceed: $canProceed
                        )
                        
                    case .audioRouting:
                        AudioRoutingStepView()
                            .onAppear { canProceed = true }
                        
                    case .audioTest:
                        AudioTestStepView(
                            settingsManager: settingsManager,
                            audioDeviceManager: audioDeviceManager,
                            canProceed: $canProceed
                        )
                        
                    case .completion:
                        CompletionStepView(
                            settingsManager: settingsManager,
                            onComplete: onComplete
                        )
                        .onAppear { canProceed = true }
                    }
                }
                .padding(32)
                .frame(maxWidth: .infinity, minHeight: 300, alignment: .top)
            }
            .background(Color(NSColor.windowBackgroundColor))
            
            // Footer Navigation
            VStack(spacing: 0) {
                Divider()
                
                HStack {
                    // Back Button
                    if currentStep != .welcome && currentStep != .completion {
                        Button("Back") {
                            withAnimation {
                                navigateBack()
                            }
                        }
                        .keyboardShortcut(.leftArrow, modifiers: [])
                    } else if currentStep == .welcome {
                        Button("Quit Setup") {
                            onClose()
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Next/Finish Button
                    if currentStep == .completion {
                        // CompletionStepView has its own Finish button, but we can have one here too
                        // or just hide this to avoid confusion.
                        // Let's keep it clean and rely on the big button in the view, 
                        // or just have a "Close" here.
                        Button("Finish") {
                            onComplete()
                        }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        
                    } else {
                        Button(currentStep == .welcome ? "Get Started" : "Next") {
                            withAnimation {
                                navigateForward()
                            }
                        }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .disabled(!canProceed)
                    }
                }
                .padding(20)
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .frame(width: 600, height: 500)
    }
    
    // MARK: - Navigation
    
    private func navigateForward() {
        guard let nextStep = WizardStep(rawValue: currentStep.rawValue + 1) else {
            return
        }
        currentStep = nextStep
    }
    
    private func navigateBack() {
        guard let prevStep = WizardStep(rawValue: currentStep.rawValue - 1) else {
            return
        }
        currentStep = prevStep
        // Reset check for backward nav usually not strictly needed but good practice
        // usually rely on onAppear of step to set canProceed
    }
}

// MARK: - Progress View

struct WizardProgressView: View {
    let currentStep: WizardStep
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(WizardStep.allCases) { step in
                HStack(spacing: 4) {
                    // Dot
                    Circle()
                        .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                    
                    // Label (only for active or past steps, or maybe all disabled)
                    if step == currentStep {
                        Text(step.title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    } else {
                        // Optional: Show labels for all steps? 
                        // Space is limited.
                    }
                    
                    // Line
                    if step != .completion {
                        Rectangle()
                            .fill(step.rawValue < currentStep.rawValue ? Color.accentColor : Color.gray.opacity(0.2))
                            .frame(width: 20, height: 2)
                    }
                }
            }
        }
    }
}
