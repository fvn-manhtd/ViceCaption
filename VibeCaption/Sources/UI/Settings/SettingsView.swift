//
//  SettingsView.swift
//  VibeCaption
//
//  Main SwiftUI view for the Settings panel with tabbed interface.
//

import SwiftUI

/// Main settings view with tabbed interface.
///
/// Provides access to all configuration sections:
/// - General: Performance and noise suppression
/// - Audio: Device selection and monitoring
/// - Overlay: Caption display customization
/// - Models: AI model management
/// - Diagnostics: System status
/// - Updates: App updates
public struct SettingsView: View {
    
    // MARK: - Properties
    
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var audioDeviceManager: AudioDeviceManager
    @ObservedObject var modelManager: ModelManager
    @ObservedObject var appStateManager: AppStateManager
    @ObservedObject var updateManager: UpdateManager
    
    // MARK: - Initialization
    
    public init(
        settingsManager: SettingsManager,
        audioDeviceManager: AudioDeviceManager,
        modelManager: ModelManager,
        appStateManager: AppStateManager,
        updateManager: UpdateManager
    ) {
        self.settingsManager = settingsManager
        self.audioDeviceManager = audioDeviceManager
        self.modelManager = modelManager
        self.appStateManager = appStateManager
        self.updateManager = updateManager
    }
    
    // MARK: - Body
    
    public var body: some View {
        TabView {
            GeneralTabView(settingsManager: settingsManager)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            AudioTabView(
                settingsManager: settingsManager,
                audioDeviceManager: audioDeviceManager
            )
                .tabItem {
                    Label("Audio", systemImage: "waveform")
                }
            
            OverlayTabView(settingsManager: settingsManager)
                .tabItem {
                    Label("Overlay", systemImage: "text.bubble")
                }
            
            ModelsTabView(
                settingsManager: settingsManager,
                modelManager: modelManager
            )
                .tabItem {
                    Label("Models", systemImage: "cpu")
                }
            
            DiagnosticsTabView(
                settingsManager: settingsManager,
                audioDeviceManager: audioDeviceManager,
                appStateManager: appStateManager,
                modelManager: modelManager
            )
                .tabItem {
                    Label("Diagnostics", systemImage: "stethoscope")
                }
            
            UpdatesTabView(
                settingsManager: settingsManager,
                updateManager: updateManager,
                modelManager: modelManager
            )
                .tabItem {
                    Label("Updates", systemImage: "arrow.down.circle")
                }
        }
        .padding()
        .frame(minWidth: 460, minHeight: 340)
    }
}

// MARK: - Preview

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let settingsManager = SettingsManager()
        SettingsView(
            settingsManager: settingsManager,
            audioDeviceManager: AudioDeviceManager(),
            modelManager: ModelManager(settingsManager: settingsManager),
            appStateManager: AppStateManager(),
            updateManager: UpdateManager(settingsManager: settingsManager)
        )
    }
}
#endif
