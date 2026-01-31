//
//  OverlayContentView.swift
//  VibeCaption
//
//  Scrollable transcript overlay content that auto-scrolls to latest
//  blocks and styles based on user settings.
//

import SwiftUI
import Combine

struct OverlayContentView: View {
    @ObservedObject var transcriptManager: TranscriptManager
    @ObservedObject var settingsManager: SettingsManager
    
    // Default visible lines count; used to shape suggested height
    let visibleLines: Int
    
    // Optional test callback for verifying auto-scroll behavior
    var onAutoScroll: ((UUID) -> Void)? = nil
    
    init(
        transcriptManager: TranscriptManager,
        settingsManager: SettingsManager,
        visibleLines: Int = 10,
        onAutoScroll: ((UUID) -> Void)? = nil
    ) {
        self.transcriptManager = transcriptManager
        self.settingsManager = settingsManager
        self.visibleLines = visibleLines
        self.onAutoScroll = onAutoScroll
    }
    
    private var containerMaxWidth: CGFloat { settingsManager.overlayMaxWidth }
    
    // Suggest height based on visible lines and font size
    private var suggestedHeight: CGFloat {
        let lineHeight = OverlayLayoutConfig.lineHeight(for: settingsManager.overlayFontSize)
        // Two lines per block typically (JP + EN). We keep visibleLines literal (lines, not blocks)
        let verticalPadding: CGFloat = 16 // padding room in ScrollView
        return CGFloat(visibleLines) * lineHeight + verticalPadding
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(transcriptManager.displayableBlocks) { block in
                        CaptionBlockView(
                            block: block,
                            fontSize: settingsManager.overlayFontSize
                        )
                        .id(block.id)
                        .animation(.easeInOut(duration: 0.25), value: transcriptManager.displayableBlocks.count)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .frame(maxWidth: containerMaxWidth, alignment: .leading)
                .onChange(of: transcriptManager.displayableBlocks.last?.id) { newID in
                    guard let newID else { return }
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(newID, anchor: .bottom)
                    }
                    onAutoScroll?(newID)
                }
            }
            .frame(maxWidth: containerMaxWidth, minHeight: suggestedHeight)
        }
    }
}

// MARK: - Layout Config (Testable)

enum OverlayLayoutConfig {
    static func lineHeight(for font: FontSize) -> CGFloat {
        // Heuristic line height multiplier
        let base = font.fontSize
        return base * 1.25
    }
    
    static func latestID(in blocks: [TranscriptBlock]) -> UUID? {
        blocks.last?.id
    }
}
