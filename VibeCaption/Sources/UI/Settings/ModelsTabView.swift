//
//  ModelsTabView.swift
//  VibeCaption
//
//  Models settings tab with AI model management.
//

import SwiftUI

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
    
    // MARK: - Body
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Model List
            List {
                ForEach(modelManager.models) { model in
                    ModelRowView(
                        model: model,
                        status: modelManager.modelStatuses[model.id] ?? .notDownloaded,
                        progress: modelManager.downloadProgress[model.id] ?? 0,
                        onDownload: {
                            Task { try? await modelManager.downloadModel(model) }
                        }
                    )
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .frame(minHeight: 150)
            
            Divider()
            
            // Disk Usage
            HStack {
                Text("Total Disk Usage:")
                    .fontWeight(.medium)
                Spacer()
                Text(formatBytes(modelManager.getTotalDiskUsage()))
                    .foregroundColor(.secondary)
            }
            
            // Storage Path
            HStack {
                Text("Storage Path:")
                    .fontWeight(.medium)
                Spacer()
                Text(settingsManager.modelStoragePath)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            // Refresh Button
            HStack {
                Spacer()
                Button("Refresh") {
                    modelManager.loadModelCatalog()
                }
                .accessibilityLabel("Refresh model catalog")
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
    let progress: Double
    let onDownload: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(model.displayName)
                        .fontWeight(.medium)
                    
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
            
            // Status Badge & Action
            statusView
        }
        .padding(.vertical, 4)
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
                ProgressView(value: downloadProgress)
                    .frame(width: 60)
                Text("\(Int(downloadProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
        case .downloaded:
            Label("Ready", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
            
        case .corrupted:
            HStack {
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
        .frame(width: 460, height: 400)
    }
}
#endif
