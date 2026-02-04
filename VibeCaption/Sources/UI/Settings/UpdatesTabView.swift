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
    
    @State private var autoUpdateEnabled: Bool = true
    @State private var isCheckingForUpdates: Bool = false
    @State private var lastCheckResult: String? = nil
    
    // MARK: - Body
    
    public var body: some View {
        Form {
            Section("Application") {
                HStack {
                    Text("Current Version")
                    Spacer()
                    Text(appVersion)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Build Number")
                    Spacer()
                    Text(buildNumber)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Automatic Updates") {
                Toggle("Enable Auto-Updates", isOn: $autoUpdateEnabled)
                
                Text("When enabled, VibeCaption will automatically download and install updates.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Manual Updates") {
                HStack {
                    Button(action: checkForUpdates) {
                        HStack {
                            if isCheckingForUpdates {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 14, height: 14)
                            }
                            Text(isCheckingForUpdates ? "Checking..." : "Check for Updates")
                        }
                    }
                    .disabled(isCheckingForUpdates)
                    
                    Spacer()
                    
                    if let result = lastCheckResult {
                        Text(result)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Model Updates") {
                Text("Model updates are managed in the Models tab. Check there for available AI model updates.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                
                HStack {
                    Spacer()
                    NavigationLink("Go to Models Tab") {
                        // This would navigate to Models tab
                        // In practice, we'd use a different approach since TabView doesn't support this directly
                        EmptyView()
                    }
                    .disabled(true) // Placeholder - cross-tab navigation not directly supported
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    // MARK: - Computed Properties
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    // MARK: - Actions
    
    private func checkForUpdates() {
        isCheckingForUpdates = true
        lastCheckResult = nil
        
        // Simulate update check - in real implementation this would use Sparkle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isCheckingForUpdates = false
            lastCheckResult = "You're up to date!"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct UpdatesTabView_Previews: PreviewProvider {
    static var previews: some View {
        UpdatesTabView()
            .frame(width: 460, height: 350)
    }
}
#endif
