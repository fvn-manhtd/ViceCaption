//
//  CaptionBlockView.swift
//  VibeCaption
//
//  Renders a single caption block with speaker badge, timestamp,
//  Japanese text, and English translation with confidence-based styling.
//

import SwiftUI

struct CaptionBlockView: View {
    let block: TranscriptBlock
    let formatter: TranscriptFormatter
    let fontSize: FontSize
    
    // Styling
    private var isLowConfidence: Bool { block.isLowConfidence }
    private var timestampString: String { formatter.formatTimestamp(block.timestamp) }
    
    init(
        block: TranscriptBlock,
        formatter: TranscriptFormatter = TranscriptFormatter(),
        fontSize: FontSize
    ) {
        self.block = block
        self.formatter = formatter
        self.fontSize = fontSize
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Speaker badge and timestamp row (badge above block per requirements)
            HStack(spacing: 8) {
                Text(block.speakerLabel ?? "Speaker 1")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor.opacity(0.15))
                    )
                    .foregroundColor(.accentColor)
                
                Text(timestampString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            
            // Japanese text (primary)
            Text(block.japaneseText)
                .font(.system(size: fontSize.fontSize, weight: .regular, design: .default))
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            
            // English text (secondary, italic), placeholder if missing
            Group {
                if let english = block.englishText, !english.isEmpty {
                    Text(english)
                        .font(.system(size: fontSize.fontSize, weight: .regular, design: .default))
                        .italic()
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    Text("Translating…")
                        .font(.system(size: fontSize.fontSize, weight: .regular, design: .default))
                        .italic()
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: block.englishText)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.001)) // subtle fill to capture hover/click if needed
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isLowConfidence ? Color.orange.opacity(0.6) : Color.secondary.opacity(0.12), lineWidth: isLowConfidence ? 1.0 : 0.5)
        )
        .opacity(isLowConfidence ? 0.95 : 1.0)
        .transition(.opacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }
    
    private var accessibilitySummary: String {
        var parts: [String] = []
        parts.append("Time \(timestampString)")
        parts.append((block.speakerLabel ?? "Speaker 1"))
        parts.append(block.japaneseText)
        parts.append(block.englishText ?? "Translating")
        return parts.joined(separator: ", ")
    }
}

// MARK: - Test Hooks

extension CaptionBlockView {
    struct Components: Equatable {
        let speaker: String
        let timestamp: String
        let japanese: String
        let englishOrPlaceholder: String
        let isLowConfidence: Bool
        let fontPointSize: CGFloat
    }
    
    static func testComponents(
        for block: TranscriptBlock,
        formatter: TranscriptFormatter = TranscriptFormatter(),
        fontSize: FontSize
    ) -> Components {
        .init(
            speaker: block.speakerLabel ?? "Speaker 1",
            timestamp: formatter.formatTimestamp(block.timestamp),
            japanese: block.japaneseText,
            englishOrPlaceholder: (block.englishText?.isEmpty == false) ? (block.englishText ?? "") : "Translating…",
            isLowConfidence: block.isLowConfidence,
            fontPointSize: fontSize.fontSize
        )
    }
}

