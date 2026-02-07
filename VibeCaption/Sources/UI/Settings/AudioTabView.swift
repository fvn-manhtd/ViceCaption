//
//  AudioTabView.swift
//  VibeCaption
//
//  Audio settings tab with device selection and monitoring options.
//

import SwiftUI

/// Audio settings tab view.
///
/// Provides:
/// - Input device picker
/// - Monitoring output device picker
/// - Audio level meter (placeholder for real-time visualization)
/// - BlackHole installation status
public struct AudioTabView: View {
    
    // MARK: - Properties
    
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var audioDeviceManager: AudioDeviceManager
    
    // MARK: - Local State
    
    @State private var audioLevel: Float = 0.0
    
    // MARK: - Bindings
    
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
    
    // MARK: - Body
    
    public var body: some View {
        Form {
            Section("Input Device") {
                Picker("Input", selection: inputDeviceBinding) {
                    Text("System Default").tag("")
                    ForEach(audioDeviceManager.inputDevices) { device in
                        Text(device.name).tag(device.uid)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Input device")
            }
            
            Section("Monitoring Output") {
                Picker("Output", selection: outputDeviceBinding) {
                    Text("System Default").tag("")
                    ForEach(audioDeviceManager.outputDevices) { device in
                        Text(device.name).tag(device.uid)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Monitoring output device")
            }
            
            Section("Audio Level") {
                AudioLevelMeterView(level: audioLevel)
                    .frame(height: 20)
                    .accessibilityLabel("Audio level meter")
                    .accessibilityValue("\(Int(min(max(audioLevel, 0), 1) * 100)) percent")
                
                Text("Audio level visualization will show when listening is active.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("BlackHole Status") {
                HStack {
                    Circle()
                        .fill(audioDeviceManager.isBlackHoleInstalled() ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    
                    Text(audioDeviceManager.isBlackHoleInstalled() 
                         ? "BlackHole is installed" 
                         : "BlackHole is not installed")
                        .foregroundColor(audioDeviceManager.isBlackHoleInstalled() 
                                        ? .primary 
                                        : .red)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("BlackHole installation status")
                
                if !audioDeviceManager.isBlackHoleInstalled() {
                    Text("BlackHole is required to capture system audio. Install from existential.audio/blackhole")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            audioDeviceManager.refreshDevices()
        }
    }
}

// MARK: - Audio Level Meter View

/// Simple audio level meter visualization.
struct AudioLevelMeterView: View {
    let level: Float // 0.0 to 1.0
    private var levelClamped: Float { min(max(level, 0), 1) }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                
                // Level bar
                RoundedRectangle(cornerRadius: 4)
                    .fill(levelColor)
                    .frame(width: geometry.size.width * CGFloat(levelClamped))
            }
        }
    }
    
    private var levelColor: Color {
        if level > 0.8 {
            return .red
        } else if level > 0.6 {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AudioTabView_Previews: PreviewProvider {
    static var previews: some View {
        AudioTabView(
            settingsManager: SettingsManager(),
            audioDeviceManager: AudioDeviceManager()
        )
        .frame(width: 460, height: 400)
    }
}
#endif
