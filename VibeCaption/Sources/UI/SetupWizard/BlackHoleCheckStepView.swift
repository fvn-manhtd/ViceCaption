//
//  BlackHoleCheckStepView.swift
//  VibeCaption
//
//  Step 2: Check for BlackHole installation.
//

import SwiftUI

struct BlackHoleCheckStepView: View {
    @ObservedObject var audioDeviceManager: AudioDeviceManager
    @Binding var canProceed: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Text("System Audio Capture")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("VibeCaption needs a virtual audio driver to capture sound from other applications.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 450)
            
            Spacer()
                .frame(height: 20)
            
            if audioDeviceManager.isBlackHoleInstalled() {
                // Success State
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .foregroundColor(.green)
                    
                    Text("BlackHole Installed")
                        .font(.title3)
                        .fontWeight(.medium)
                    
                    Text("The BlackHole virtual audio driver was detected. You're ready to proceed.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(30)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                )
                .onAppear {
                    canProceed = true
                }
                
            } else {
                // Not Installed State
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .foregroundColor(.orange)
                    
                    Text("BlackHole Required")
                        .font(.title3)
                        .fontWeight(.medium)
                    
                    Text("Please download and install the 2ch version of BlackHole.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Link("Download BlackHole Installer", destination: URL(string: "https://github.com/ExistentialAudio/BlackHole/releases")!)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.top, 8)
                    
                    Text("After installing, click 'Check Again'.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .padding(30)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                )
                
                Button("Check Again") {
                    audioDeviceManager.refreshDevices()
                    if audioDeviceManager.isBlackHoleInstalled() {
                        canProceed = true
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .onAppear {
                    canProceed = false
                    // Also check on appear in case they installed it while wizard was closed/hidden
                    audioDeviceManager.refreshDevices()
                    if audioDeviceManager.isBlackHoleInstalled() {
                        canProceed = true
                    }
                }
            }
            
            Spacer()
        }
    }
}
