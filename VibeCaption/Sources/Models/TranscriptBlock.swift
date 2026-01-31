//
//  TranscriptBlock.swift
//  VibeCaption
//
//  Model representing a single transcript block with Japanese text,
//  optional English translation, speaker label, and confidence score.
//

import Foundation

// MARK: - TranscriptBlock

/// Represents a single block of transcribed text with metadata.
///
/// A transcript block contains the Japanese transcription, an optional
/// English translation (nil until translation completes), speaker
/// identification, and confidence metrics.
///
/// Example:
/// ```swift
/// let block = TranscriptBlock(
///     japaneseText: "こんにちは",
///     speakerLabel: "Speaker 1",
///     confidence: 0.95
/// )
/// print(block.isLowConfidence) // false
/// ```
public struct TranscriptBlock: Identifiable, Equatable, Codable {
    
    // MARK: - Properties
    
    /// Unique identifier for this block.
    public let id: UUID
    
    /// Wall-clock timestamp when this block was captured.
    public let timestamp: Date
    
    /// Optional speaker label (e.g., "Speaker 1", "Speaker 2").
    public let speakerLabel: String?
    
    /// The transcribed Japanese text.
    public let japaneseText: String
    
    /// The English translation. `nil` until translation is complete.
    public var englishText: String?
    
    /// Confidence score from ASR (0.0 to 1.0).
    public let confidence: Double
    
    // MARK: - Computed Properties
    
    /// Indicates whether the confidence is below the threshold (< 0.7).
    ///
    /// Low confidence blocks may be styled differently in the UI
    /// to indicate potential transcription errors.
    public var isLowConfidence: Bool {
        confidence < 0.7
    }
    
    // MARK: - Constants
    
    /// The threshold below which confidence is considered low.
    public static let lowConfidenceThreshold: Double = 0.7
    
    // MARK: - Initialization
    
    /// Creates a new transcript block.
    ///
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a new UUID.
    ///   - timestamp: Wall-clock time of capture. Defaults to current time.
    ///   - speakerLabel: Optional speaker identification.
    ///   - japaneseText: The transcribed Japanese text.
    ///   - englishText: Optional English translation.
    ///   - confidence: ASR confidence score (0.0-1.0).
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        speakerLabel: String? = nil,
        japaneseText: String,
        englishText: String? = nil,
        confidence: Double
    ) {
        self.id = id
        self.timestamp = timestamp
        self.speakerLabel = speakerLabel
        self.japaneseText = japaneseText
        self.englishText = englishText
        self.confidence = max(0.0, min(1.0, confidence)) // Clamp to valid range
    }
}
