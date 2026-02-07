//
//  UpdatesTabView.swift
//  VibeCaption
//
//  Updates settings tab with version info and auto-update controls.
//

import SwiftUI

/// Updates settings tab view.
///
/// Provides:
/// - Current version display
/// - Auto-update toggle
/// - Check for updates button
/// - Model update prompts
public struct UpdatesTabView: View {
    
    // MARK: - Properties
    
    @ObservedObject private var settingsManager: SettingsManager
    @ObservedObject private var updateManager: UpdateManager
    @ObservedObject private var modelManager: ModelManager

    @State private var isCheckingModels: Bool = false
    @State private var modelUpdateError: String?

    // MARK: - Initialization

    public init(
        settingsManager: SettingsManager,
        updateManager: UpdateManager,
        modelManager: ModelManager
    ) {
        self.settingsManager = settingsManager
        self.updateManager = updateManager
        self.modelManager = modelManager
    }
    
    // MARK: - Body
    
    public var body: some View {
        Form {
            Section("Application") {
                HStack {
                    Text("Current Version")
                    Spacer()
                    Text(updateManager.currentVersion)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Build Number")
                    Spacer()
                    Text(updateManager.currentBuild)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Automatic Updates") {
                Toggle(
                    "Enable Auto-Updates",
                    isOn: Binding(
                        get: { updateManager.automaticallyChecksForUpdates },
                        set: { updateManager.setAutomaticAppUpdatesEnabled($0) }
                    )
                )
                .accessibilityLabel("Enable automatic app updates")

                HStack {
                    Text("Check Frequency")
                    Spacer()
                    Picker(
                        "Check Frequency",
                        selection: Binding(
                            get: { updateManager.appUpdateCheckIntervalHours },
                            set: { updateManager.setAppUpdateCheckInterval(hours: $0) }
                        )
                    ) {
                        Text("Every 6 hours").tag(6)
                        Text("Every 12 hours").tag(12)
                        Text("Daily").tag(24)
                        Text("Every 3 days").tag(72)
                        Text("Weekly").tag(168)
                    }
                    .frame(maxWidth: 170)
                }

                Toggle(
                    "Force Critical Security Updates",
                    isOn: Binding(
                        get: { settingsManager.enforceCriticalAppUpdates },
                        set: { settingsManager.enforceCriticalAppUpdates = $0 }
                    )
                )
                .accessibilityLabel("Force critical security updates")

                Text("Critical update enforcement is controlled by appcast metadata and this local policy.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Manual Updates") {
                HStack {
                    Button(action: checkForUpdates) {
                        HStack {
                            if updateManager.isCheckingForUpdates {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 14, height: 14)
                            }
                            Text(updateManager.isCheckingForUpdates ? "Checking..." : "Check for Updates")
                        }
                    }
                    .disabled(updateManager.isCheckingForUpdates)
                    .accessibilityLabel("Check for app updates")
                    
                    Spacer()
                }

                HStack {
                    Text("Last Checked")
                    Spacer()
                    Text(formattedDate(updateManager.lastCheckedAt))
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Model Updates") {
                TextField(
                    "Model Catalog URL",
                    text: Binding(
                        get: { settingsManager.modelCatalogURL?.absoluteString ?? "" },
                        set: { value in
                            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                            settingsManager.modelCatalogURL = trimmed.isEmpty ? nil : URL(string: trimmed)
                        }
                    )
                )

                HStack {
                    Button(action: checkModelUpdates) {
                        HStack {
                            if isCheckingModels {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 14, height: 14)
                            }
                            Text(isCheckingModels ? "Checking..." : "Check Model Updates")
                        }
                    }
                    .disabled(isCheckingModels)
                    .accessibilityLabel("Check for model updates")

                    Spacer()
                }

                HStack {
                    Text("Last Checked")
                    Spacer()
                    Text(formattedDate(settingsManager.modelLastUpdateCheckDate))
                        .foregroundColor(.secondary)
                }

                if let modelUpdateError {
                    Text(modelUpdateError)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                if modelManager.availableModelUpdates.isEmpty {
                    Text("No model updates found.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(modelManager.availableModelUpdates) { update in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(update.latestModel.displayName)
                                    .font(.callout)
                                Text("Installed \(update.currentVersion) → Latest \(update.latestVersion)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Download") {
                                downloadModelUpdate(update)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Download model update for \(update.latestModel.displayName)")
                        }
                    }
                }

                Text("Model update checks only run when you trigger them from Settings.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            updateManager.refreshLastCheckedDate()
        }
    }
    
    // MARK: - Actions
    
    private func checkForUpdates() {
        updateManager.checkForAppUpdates()
    }

    private func checkModelUpdates() {
        guard settingsManager.modelCatalogURL != nil else {
            modelUpdateError = "Set a model catalog URL before checking for model updates."
            return
        }

        isCheckingModels = true
        modelUpdateError = nil

        Task {
            do {
                _ = try await modelManager.checkForModelUpdates(catalogURL: settingsManager.modelCatalogURL)
                settingsManager.modelLastUpdateCheckDate = Date()
            } catch {
                modelUpdateError = "Model update check failed: \(error.localizedDescription)"
            }
            isCheckingModels = false
        }
    }

    private func downloadModelUpdate(_ update: ModelUpdate) {
        Task {
            do {
                try await modelManager.downloadModel(update.latestModel)
            } catch {
                modelUpdateError = "Download failed for \(update.latestModel.displayName): \(error.localizedDescription)"
            }
        }
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "Never" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

// MARK: - Preview

#if DEBUG
struct UpdatesTabView_Previews: PreviewProvider {
    static var previews: some View {
        let settings = SettingsManager()
        let modelManager = ModelManager(settingsManager: settings)
        UpdatesTabView(
            settingsManager: settings,
            updateManager: UpdateManager(settingsManager: settings),
            modelManager: modelManager
        )
            .frame(width: 460, height: 350)
    }
}
#endif
