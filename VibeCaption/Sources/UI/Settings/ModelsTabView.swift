//
//  ModelsTabView.swift
//  VibeCaption
//
//  Models settings tab with AI model management.
//

import SwiftUI
import AppKit

/// Models settings tab view.
///
/// Provides:
/// - List of required AI models with status
/// - Download/Update buttons per model
/// - Total disk usage
/// - Model storage path display
public struct ModelsTabView: View {

    // MARK: - Properties

    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var modelManager: ModelManager

    private var installedModelCount: Int {
        modelManager.models.filter { modelManager.modelStatuses[$0.id]?.isReady == true }.count
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Installed \(installedModelCount) of \(modelManager.models.count) models")
                        .font(.headline)
                    Text("Manage local AI models used by transcription and translation.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Refresh Catalog") {
                    modelManager.loadModelCatalog()
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Refresh model catalog")
            }

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(modelManager.models) { model in
                        ModelRowView(
                            model: model,
                            status: modelManager.modelStatuses[model.id] ?? .notDownloaded,
                            onDownload: {
                                Task { try? await modelManager.downloadModel(model) }
                            }
                        )
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(minHeight: 220)

            Divider()

            HStack {
                Text("Total Disk Usage")
                    .fontWeight(.medium)
                Spacer()
                Text(formatBytes(modelManager.getTotalDiskUsage()))
                    .foregroundColor(.secondary)
            }

            HStack(alignment: .center, spacing: 12) {
                Text("Storage Path")
                    .fontWeight(.medium)

                Text(settingsManager.modelStoragePath)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button("Open Folder") {
                    let storageURL = URL(fileURLWithPath: settingsManager.modelStoragePath, isDirectory: true)
                    NSWorkspace.shared.activateFileViewerSelecting([storageURL])
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Open model storage folder")
            }
        }
        .padding()
        .onAppear {
            if modelManager.models.isEmpty {
                modelManager.loadModelCatalog()
            }
        }
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Model Row View

/// Individual model row showing name, version, status, and actions.
struct ModelRowView: View {
    let model: ModelInfo
    let status: ModelStatus
    let onDownload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(model.displayName)
                            .fontWeight(.semibold)

                        if model.isRequired {
                            Text("Required")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }

                    HStack(spacing: 12) {
                        Text("v\(model.version)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(formatBytes(model.sizeBytes))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                statusView
            }

            if case .downloading(let progress) = status {
                ProgressView(value: progress)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .notDownloaded:
            Button("Download") {
                onDownload()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .accessibilityLabel("Download \(model.displayName)")

        case .downloading(let downloadProgress):
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(.blue)
                Text("\(Int(downloadProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

        case .downloaded:
            Label("Ready", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)

        case .corrupted:
            HStack(spacing: 8) {
                Label("Corrupted", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.caption)

                Button("Re-download") {
                    onDownload()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Re-download \(model.displayName)")
            }

        case .updateAvailable:
            Button("Update") {
                onDownload()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Update \(model.displayName)")
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Preview

#if DEBUG
struct ModelsTabView_Previews: PreviewProvider {
    static var previews: some View {
        ModelsTabView(
            settingsManager: SettingsManager(),
            modelManager: ModelManager(settingsManager: SettingsManager())
        )
        .frame(width: 640, height: 460)
    }
}
#endif
