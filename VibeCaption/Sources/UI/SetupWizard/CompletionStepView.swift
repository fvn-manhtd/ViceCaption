//
//  CompletionStepView.swift
//  VibeCaption
//
//  Step 5: Completion and summary.
//

import SwiftUI

struct CompletionStepView: View {
    @ObservedObject var settingsManager: SettingsManager
    var onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "checkmark.seal.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
             
            Text("All Set!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("VibeCaption is properly configured and ready to transcribe.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Configuration Summary:")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                HStack {
                    Text("Input:")
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .leading)
                    Text(inputDeviceName)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Output:")
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .leading)
                    Text(outputDeviceName)
                        .fontWeight(.medium)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .padding(.horizontal, 40)
            
            Spacer()
            
            Button("Open Overlay & Finish") {
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .font(.headline)
            
            Spacer()
        }
    }
    
    private var inputDeviceName: String {
        // Ideally look up name from ID, but for summary we might need device list
        // Since we don't have it passed here easily, we'll genericize if ID exists
        if let _ = settingsManager.audioInputDeviceID {
            return "Custom Device (BlackHole)" // Simplification for UI
        } else {
            return "System Default"
        }
    }
    
    private var outputDeviceName: String {
        if let _ = settingsManager.monitoringOutputDeviceID {
            return "Custom Device"
        } else {
            return "System Default"
        }
    }
}
