//
//  GeneralTabView.swift
//  VibeCaption
//
//  General settings tab with performance and noise suppression options.
//

import SwiftUI

/// General settings tab view.
///
/// Provides toggles for:
/// - Performance mode (reduces quality for lower CPU usage)
/// - Noise suppression (audio cleanup during capture)
public struct GeneralTabView: View {
    
    // MARK: - Properties
    
    @ObservedObject var settingsManager: SettingsManager
    
    // MARK: - Bindings
    
    private var performanceModeBinding: Binding<Bool> {
        Binding(
            get: { settingsManager.performanceModeEnabled },
            set: { settingsManager.performanceModeEnabled = $0 }
        )
    }
    
    private var noiseSuppressionBinding: Binding<Bool> {
        Binding(
            get: { settingsManager.noiseSuppressionEnabled },
            set: { settingsManager.noiseSuppressionEnabled = $0 }
        )
    }
    
    // MARK: - Body
    
    public var body: some View {
        Form {
            Section {
                Toggle("Performance Mode", isOn: performanceModeBinding)
                Text("Reduces transcription quality to lower CPU usage.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section {
                Toggle("Noise Suppression", isOn: noiseSuppressionBinding)
                Text("Filters background noise from audio input.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Preview

#if DEBUG
struct GeneralTabView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralTabView(settingsManager: SettingsManager())
            .frame(width: 460, height: 300)
    }
}
#endif
