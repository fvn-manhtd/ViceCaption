//
//  OverlayTabView.swift
//  VibeCaption
//
//  Overlay settings tab with caption display customization.
//

import SwiftUI

/// Overlay settings tab view.
///
/// Provides customization for:
/// - Font size (Small/Medium/Large)
/// - Maximum width (320-800px)
/// - Auto-hide duration (15s/30s/60s/Never)
/// - Live preview of current settings
public struct OverlayTabView: View {
    
    // MARK: - Constants
    
    private enum AutoHideOption: Int, CaseIterable, Identifiable {
        case seconds15 = 15
        case seconds30 = 30
        case seconds60 = 60
        case never = 0
        
        var id: Int { rawValue }
        
        var displayName: String {
            switch self {
            case .seconds15: return "15 seconds"
            case .seconds30: return "30 seconds"
            case .seconds60: return "60 seconds"
            case .never: return "Never"
            }
        }
    }
    
    // MARK: - Properties
    
    @ObservedObject var settingsManager: SettingsManager
    
    // MARK: - Bindings
    
    private var fontSizeBinding: Binding<FontSize> {
        Binding(
            get: { settingsManager.overlayFontSize },
            set: { settingsManager.overlayFontSize = $0 }
        )
    }
    
    private var maxWidthBinding: Binding<CGFloat> {
        Binding(
            get: { settingsManager.overlayMaxWidth },
            set: { settingsManager.overlayMaxWidth = $0 }
        )
    }
    
    private var autoHideBinding: Binding<AutoHideOption> {
        Binding(
            get: { 
                AutoHideOption(rawValue: settingsManager.overlayAutoHideSeconds) ?? .seconds30 
            },
            set: { settingsManager.overlayAutoHideSeconds = $0.rawValue }
        )
    }
    
    // MARK: - Body
    
    public var body: some View {
        Form {
            Section("Font Size") {
                Picker("Size", selection: fontSizeBinding) {
                    ForEach(FontSize.allCases, id: \.self) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Overlay font size")
            }
            
            Section("Maximum Width") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Width:")
                        Spacer()
                        Text("\(Int(settingsManager.overlayMaxWidth))px")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: maxWidthBinding,
                        in: 320...800,
                        step: 20
                    )
                    .accessibilityLabel("Overlay max width")
                }
            }
            
            Section("Auto-Hide Duration") {
                Picker("Hide after", selection: autoHideBinding) {
                    ForEach(AutoHideOption.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Overlay auto hide duration")
                
                Text("Overlay will hide after this duration of inactivity.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Preview") {
                OverlayPreviewView(
                    fontSize: settingsManager.overlayFontSize,
                    maxWidth: settingsManager.overlayMaxWidth
                )
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Preview View

/// Shows a preview of how captions will appear with current settings.
struct OverlayPreviewView: View {
    let fontSize: FontSize
    let maxWidth: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Speaker 1")
                    .font(.system(size: fontSize.fontSize, weight: .semibold))
                    .foregroundColor(.blue)
                
                Text("00:15")
                    .font(.system(size: fontSize.fontSize * 0.85))
                    .foregroundColor(.secondary)
            }
            
            Text("こんにちは、お元気ですか？")
                .font(.system(size: fontSize.fontSize))
            
            Text("Hello, how are you?")
                .font(.system(size: fontSize.fontSize))
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: maxWidth)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - Preview

#if DEBUG
struct OverlayTabView_Previews: PreviewProvider {
    static var previews: some View {
        OverlayTabView(settingsManager: SettingsManager())
            .frame(width: 460, height: 450)
    }
}
#endif
