//
//  SettingsView.swift
//  VibeCaption
//
//  Main SwiftUI view for the Settings panel with sidebar navigation.
//

import SwiftUI

/// Main settings view with sidebar navigation.
///
/// Provides access to all configuration sections:
/// - General: Performance and noise suppression
/// - Audio: Device selection and monitoring
/// - Overlay: Caption display customization
/// - Models: AI model management
/// - Diagnostics: System status
/// - Updates: App updates
public struct SettingsView: View {

    private enum SettingsSection: String, CaseIterable, Identifiable {
        case general
        case audio
        case overlay
        case models
        case diagnostics
        case updates

        var id: String { rawValue }

        var title: String {
            switch self {
            case .general: return "General"
            case .audio: return "Audio"
            case .overlay: return "Overlay"
            case .models: return "Models"
            case .diagnostics: return "Diagnostics"
            case .updates: return "Updates"
            }
        }

        var systemImage: String {
            switch self {
            case .general: return "gearshape"
            case .audio: return "waveform"
            case .overlay: return "text.bubble"
            case .models: return "cpu"
            case .diagnostics: return "stethoscope"
            case .updates: return "arrow.down.circle"
            }
        }
    }
    
    // MARK: - Properties
    
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var audioDeviceManager: AudioDeviceManager
    @ObservedObject var modelManager: ModelManager
    @ObservedObject var appStateManager: AppStateManager
    @ObservedObject var updateManager: UpdateManager
    @ObservedObject var pipeline: CaptionPipeline
    @State private var selectedSection: SettingsSection = .general
    
    // MARK: - Initialization
    
    public init(
        settingsManager: SettingsManager,
        audioDeviceManager: AudioDeviceManager,
        modelManager: ModelManager,
        appStateManager: AppStateManager,
        updateManager: UpdateManager,
        pipeline: CaptionPipeline
    ) {
        self.settingsManager = settingsManager
        self.audioDeviceManager = audioDeviceManager
        self.modelManager = modelManager
        self.appStateManager = appStateManager
        self.updateManager = updateManager
        self.pipeline = pipeline
    }
    
    // MARK: - Body
    
    public var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(SettingsSection.allCases) { section in
                    Button {
                        selectedSection = section
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: section.systemImage)
                                .frame(width: 14)
                            Text(section.title)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    selectedSection == section
                                    ? Color.accentColor.opacity(0.18)
                                    : Color.clear
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .frame(minWidth: 190, idealWidth: 200, maxWidth: 220)

            Divider()

            VStack(spacing: 0) {
                HStack {
                    Text(selectedSection.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

                Divider()

                selectedContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(minWidth: 760, minHeight: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .animation(.easeInOut(duration: 0.2), value: selectedSection)
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedSection {
        case .general:
            GeneralTabView(settingsManager: settingsManager)
        case .audio:
            AudioTabView(
                settingsManager: settingsManager,
                audioDeviceManager: audioDeviceManager,
                pipeline: pipeline
            )
        case .overlay:
            OverlayTabView(settingsManager: settingsManager)
        case .models:
            ModelsTabView(
                settingsManager: settingsManager,
                modelManager: modelManager
            )
        case .diagnostics:
            DiagnosticsTabView(
                settingsManager: settingsManager,
                audioDeviceManager: audioDeviceManager,
                appStateManager: appStateManager,
                modelManager: modelManager
            )
        case .updates:
            UpdatesTabView(
                settingsManager: settingsManager,
                updateManager: updateManager,
                modelManager: modelManager
            )
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let settingsManager = SettingsManager()
        let appStateManager = AppStateManager()
        let transcriptManager = TranscriptManager(settingsManager: settingsManager)
        let pipeline = CaptionPipeline(
            asrService: MockASRService(),
            translationService: MockTranslationService(),
            transcriptManager: transcriptManager,
            appStateManager: appStateManager,
            settingsManager: settingsManager
        )

        SettingsView(
            settingsManager: settingsManager,
            audioDeviceManager: AudioDeviceManager(),
            modelManager: ModelManager(settingsManager: settingsManager),
            appStateManager: appStateManager,
            updateManager: UpdateManager(settingsManager: settingsManager),
            pipeline: pipeline
        )
    }
}
#endif
