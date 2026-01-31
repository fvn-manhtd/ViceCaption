//
//  TranscriptFormatter.swift
//  VibeCaption
//
//  Formats transcript blocks and sessions for display and file output.
//

import Foundation

#if canImport(AppKit)
import AppKit
#endif

// MARK: - TranscriptFormatter

/// Provides formatting utilities for transcript blocks and sessions.
///
/// This class handles two types of formatting:
/// 1. Display formatting - AttributedString for the overlay UI
/// 2. File formatting - Plain text for saving to transcript files
///
/// Example:
/// ```swift
/// let formatter = TranscriptFormatter()
/// let displayText = formatter.formatForDisplay(block: block)
/// let fileContent = formatter.formatForFile(session: session)
/// ```
public final class TranscriptFormatter {
    
    // MARK: - Properties
    
    /// Date formatter for wall-clock timestamps (HH:MM:SS).
    private let timestampFormatter: DateFormatter
    
    /// Date formatter for filename generation (YYYY-MM-DD_HHmm).
    private let filenameFormatter: DateFormatter
    
    // MARK: - Initialization
    
    /// Creates a new transcript formatter.
    public init() {
        // Configure timestamp formatter for HH:MM:SS
        timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "HH:mm:ss"
        timestampFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        // Configure filename formatter for YYYY-MM-DD_HHmm
        filenameFormatter = DateFormatter()
        filenameFormatter.dateFormat = "yyyy-MM-dd_HHmm"
        filenameFormatter.locale = Locale(identifier: "en_US_POSIX")
    }
    
    // MARK: - Timestamp Formatting
    
    /// Formats a date as a wall-clock timestamp string.
    ///
    /// - Parameter date: The date to format.
    /// - Returns: A string in HH:MM:SS format.
    public func formatTimestamp(_ date: Date) -> String {
        timestampFormatter.string(from: date)
    }
    
    // MARK: - Display Formatting
    
    /// Formats a transcript block for overlay display.
    ///
    /// - Parameter block: The transcript block to format.
    /// - Returns: An AttributedString styled for overlay display.
    public func formatForDisplay(block: TranscriptBlock) -> AttributedString {
        var result = AttributedString()
        
        // Timestamp and speaker header
        var headerText = "[\(formatTimestamp(block.timestamp))]"
        if let speaker = block.speakerLabel {
            headerText += " (\(speaker))"
        }
        headerText += "\n"
        
        var header = AttributedString(headerText)
        header.foregroundColor = .gray
        result.append(header)
        
        // Japanese text
        var japaneseText = AttributedString(block.japaneseText + "\n")
        if block.isLowConfidence {
            japaneseText.foregroundColor = .orange
        }
        result.append(japaneseText)
        
        // English text (if available)
        if let english = block.englishText {
            var englishText = AttributedString(english)
            englishText.foregroundColor = .secondary
            result.append(englishText)
        }
        
        return result
    }
    
    /// Formats a pause marker for overlay display.
    ///
    /// - Parameter marker: The pause marker to format.
    /// - Returns: An AttributedString styled for overlay display.
    public func formatForDisplay(marker: PauseMarker) -> AttributedString {
        var result = AttributedString("[\(formatTimestamp(marker.timestamp))] [PAUSED]")
        result.foregroundColor = .gray
        return result
    }
    
    // MARK: - File Formatting
    
    /// Formats a transcript block for file output.
    ///
    /// Format:
    /// ```
    /// [HH:MM:SS] (Speaker X)
    /// Japanese text here
    /// English text here
    /// ```
    ///
    /// - Parameter block: The transcript block to format.
    /// - Returns: A plain text string.
    public func formatBlockForFile(_ block: TranscriptBlock) -> String {
        var lines: [String] = []
        
        // Header line with timestamp and optional speaker
        var header = "[\(formatTimestamp(block.timestamp))]"
        if let speaker = block.speakerLabel {
            header += " (\(speaker))"
        }
        lines.append(header)
        
        // Japanese text
        lines.append(block.japaneseText)
        
        // English text (if available)
        if let english = block.englishText {
            lines.append(english)
        }
        
        return lines.joined(separator: "\n")
    }
    
    /// Formats a pause marker for file output.
    ///
    /// Format: `[HH:MM:SS] [PAUSED]`
    ///
    /// - Parameter marker: The pause marker to format.
    /// - Returns: A plain text string.
    public func formatMarkerForFile(_ marker: PauseMarker) -> String {
        "[\(formatTimestamp(marker.timestamp))] [PAUSED]"
    }
    
    /// Formats an entire session for file output.
    ///
    /// This method interleaves blocks and pause markers in chronological order.
    ///
    /// - Parameter session: The transcript session to format.
    /// - Returns: A plain text string representing the entire session.
    public func formatForFile(session: TranscriptSession) -> String {
        // Create a combined list of all items with their timestamps
        var items: [(date: Date, content: String)] = []
        
        for block in session.blocks {
            items.append((block.timestamp, formatBlockForFile(block)))
        }
        
        for marker in session.pauseMarkers {
            items.append((marker.timestamp, formatMarkerForFile(marker)))
        }
        
        // Sort by timestamp
        items.sort { $0.date < $1.date }
        
        // Join with blank lines between entries
        return items.map { $0.content }.joined(separator: "\n\n")
    }
    
    // MARK: - Filename Generation
    
    /// Generates a filename for a session transcript file.
    ///
    /// Format: `YYYY-MM-DD_HHmm_VibeCaption.txt`
    ///
    /// - Parameter session: The session to generate a filename for.
    /// - Returns: The generated filename.
    public func generateFilename(for session: TranscriptSession) -> String {
        let dateString = filenameFormatter.string(from: session.startTime)
        return "\(dateString)_VibeCaption.txt"
    }
    
    /// Generates a filename for a custom date.
    ///
    /// - Parameter date: The date to use for the filename.
    /// - Returns: The generated filename.
    public func generateFilename(for date: Date) -> String {
        let dateString = filenameFormatter.string(from: date)
        return "\(dateString)_VibeCaption.txt"
    }
}
