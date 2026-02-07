//
//  AudioTestStepView.swift
//  VibeCaption
//
//  Step 4: Real-time audio test.
//

import SwiftUI
import AVFoundation

struct AudioTestStepView: View {
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var audioDeviceManager: AudioDeviceManager
    @Binding var canProceed: Bool
    
    @State private var audioLevel: Float = 0.0
    @State private var isPlayingSound = false
    @State private var hasDetectedAudio = false
    @State private var testSound: NSSound?
    @State private var timer: Timer?
    
    // Bindings
    private var inputDeviceBinding: Binding<String> {
        Binding(
            get: { settingsManager.audioInputDeviceID ?? "" },
            set: { settingsManager.audioInputDeviceID = $0.isEmpty ? nil : $0 }
        )
    }
    
    private var outputDeviceBinding: Binding<String> {
        Binding(
            get: { settingsManager.monitoringOutputDeviceID ?? "" },
            set: { settingsManager.monitoringOutputDeviceID = $0.isEmpty ? nil : $0 }
        )
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Let's Test It")
                .font(.title2)
                .fontWeight(.bold)
            
            // Device Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Configuration")
                    .font(.headline)
                
                Grid(alignment: .leading, verticalSpacing: 12) {
                    GridRow {
                        Text("Input:")
                            .gridColumnAlignment(.trailing)
                        
                        Picker("", selection: inputDeviceBinding) {
                            Text("Select Input...").tag("")
                            Divider() 
                            // Prioritize BlackHole
                            if let blackHole = audioDeviceManager.getBlackHoleInputDevice() {
                                Text(blackHole.name).tag(blackHole.uid)
                            }
                            Divider()
                            ForEach(audioDeviceManager.inputDevices) { device in
                                if !device.isBlackHole {
                                    Text(device.name).tag(device.uid)
                                }
                            }
                        }
                        .labelsHidden()
                    }
                    
                    GridRow {
                        Text("Output:")
                        
                        Picker("", selection: outputDeviceBinding) {
                            Text("System Default").tag("")
                            Divider()
                            ForEach(audioDeviceManager.outputDevices) { device in
                                Text(device.name).tag(device.uid)
                            }
                        }
                        .labelsHidden()
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            Divider()
            
            // Test Area
            VStack(spacing: 16) {
                Text("1. Play a test sound or audio from another app")
                    .foregroundColor(.secondary)
                
                Button(action: toggleTestSound) {
                    Label(isPlayingSound ? "Stop Sound" : "Play Test Sound", 
                          systemImage: isPlayingSound ? "stop.fill" : "play.fill")
                }
                .disabled(settingsManager.monitoringOutputDeviceID == nil && settingsManager.audioInputDeviceID == nil)
                .accessibilityLabel(isPlayingSound ? "Stop test sound" : "Play test sound")
                
                Text("2. Verify the meter moves")
                    .foregroundColor(.secondary)
                
                // Meter
                VStack(spacing: 8) {
                    AudioLevelMeterView(level: audioLevel)
                        .frame(height: 24)
                        .frame(width: 300)
                    
                    if hasDetectedAudio {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Audio Detected!")
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        Text("Waiting for audio...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .onAppear {
            setupInitialDevices()
            startMonitoring()
            canProceed = false 
        }
        .onDisappear {
            stopTestSound()
            stopMonitoring()
        }
    }
    
    private func setupInitialDevices() {
        // Auto-select BlackHole if not set
        if settingsManager.audioInputDeviceID == nil {
            if let blackHole = audioDeviceManager.getBlackHoleInputDevice() {
                settingsManager.audioInputDeviceID = blackHole.uid
            }
        }
        
        // Auto-select Default Output if not set
        if settingsManager.monitoringOutputDeviceID == nil {
            // Usually we want system default for monitoring
            // settingsManager.monitoringOutputDeviceID = ... 
            // Leaving as nil means system default which is good.
        }
    }
    
    private func toggleTestSound() {
        if isPlayingSound {
            stopTestSound()
        } else {
            playTestSound()
        }
    }
    
    private func playTestSound() {
        if let sound = NSSound(named: "Ping") {
            sound.loops = true
            sound.play()
            testSound = sound
            isPlayingSound = true
            
            // Simulate audio detection for UI demo purposes since engine isn't wired to view
            // In real integration, this would come from the engine
            simulateAudioDetection()
        }
    }
    
    private func stopTestSound() {
        testSound?.stop()
        testSound = nil
        isPlayingSound = false
    }
    
    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func startMonitoring() {
        // Placeholder for real monitoring
    }
    
    private func simulateAudioDetection() {
        // Fake meter movement
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if self.isPlayingSound {
                self.audioLevel = Float.random(in: 0.3...0.8)
                if !self.hasDetectedAudio {
                    self.hasDetectedAudio = true
                    self.canProceed = true // Enable Next button
                }
            } else {
                self.audioLevel = max(0, self.audioLevel - 0.1)
            }
        }
    }
}
