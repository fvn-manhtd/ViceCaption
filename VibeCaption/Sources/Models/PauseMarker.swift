//
//  PauseMarker.swift
//  VibeCaption
//
//  Model representing a pause event in the transcript timeline.
//

import Foundation

// MARK: - PauseMarker

/// Represents a pause marker in the transcript timeline.
///
/// Pause markers are inserted when the user pauses transcription
/// and are displayed in both the overlay and saved transcript files.
///
/// Example:
/// ```swift
/// let pauseMarker = PauseMarker()
/// print(pauseMarker.timestamp) // Current time
/// ```
public struct PauseMarker: Identifiable, Equatable, Codable {
    
    // MARK: - Properties
    
    /// Unique identifier for this pause marker.
    public let id: UUID
    
    /// Wall-clock timestamp when the pause occurred.
    public let timestamp: Date
    
    // MARK: - Initialization
    
    /// Creates a new pause marker.
    ///
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a new UUID.
    ///   - timestamp: Wall-clock time of pause. Defaults to current time.
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date()
    ) {
        self.id = id
        self.timestamp = timestamp
    }
}
