//
//  TranscriptSession.swift
//  VibeCaption
//
//  Model representing a complete transcript session containing
//  transcript blocks and pause markers.
//

import Foundation

// MARK: - TranscriptSession

/// Represents a transcript session containing blocks and pause markers.
///
/// A session represents a continuous period of transcription from start
/// to end. It contains ordered transcript blocks and pause markers that
/// can be formatted for display or saved to a file.
///
/// Example:
/// ```swift
/// var session = TranscriptSession()
/// let block = TranscriptBlock(japaneseText: "こんにちは", confidence: 0.95)
/// session.addBlock(block)
/// session.addPauseMarker(PauseMarker())
/// session.endSession()
/// ```
public struct TranscriptSession: Identifiable, Equatable, Codable {
    
    // MARK: - Properties
    
    /// Unique identifier for this session.
    public let id: UUID
    
    /// Wall-clock timestamp when the session started.
    public let startTime: Date
    
    /// Wall-clock timestamp when the session ended. `nil` if still active.
    public private(set) var endTime: Date?
    
    /// Ordered list of transcript blocks in this session.
    public private(set) var blocks: [TranscriptBlock]
    
    /// Ordered list of pause markers in this session.
    public private(set) var pauseMarkers: [PauseMarker]
    
    // MARK: - Computed Properties
    
    /// Returns `true` if the session is still active (no end time set).
    public var isActive: Bool {
        endTime == nil
    }
    
    /// Total number of items (blocks + pause markers) in the session.
    public var totalItemCount: Int {
        blocks.count + pauseMarkers.count
    }
    
    /// Duration of the session, or time elapsed if still active.
    public var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }
    
    // MARK: - Initialization
    
    /// Creates a new transcript session.
    ///
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a new UUID.
    ///   - startTime: Wall-clock time of session start. Defaults to current time.
    ///   - blocks: Initial blocks. Defaults to empty.
    ///   - pauseMarkers: Initial pause markers. Defaults to empty.
    public init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        blocks: [TranscriptBlock] = [],
        pauseMarkers: [PauseMarker] = []
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = nil
        self.blocks = blocks
        self.pauseMarkers = pauseMarkers
    }
    
    // MARK: - Mutating Methods
    
    /// Adds a transcript block to the session.
    ///
    /// - Parameter block: The block to add.
    public mutating func addBlock(_ block: TranscriptBlock) {
        blocks.append(block)
    }
    
    /// Adds a pause marker to the session.
    ///
    /// - Parameter marker: The pause marker to add.
    public mutating func addPauseMarker(_ marker: PauseMarker) {
        pauseMarkers.append(marker)
    }
    
    /// Marks the session as ended with the current timestamp.
    public mutating func endSession() {
        endTime = Date()
    }
    
    /// Marks the session as ended with a specific timestamp.
    ///
    /// - Parameter time: The end time to set.
    public mutating func endSession(at time: Date) {
        endTime = time
    }

    /// Updates an existing block with translated English text.
    ///
    /// - Parameters:
    ///   - id: The identifier of the block to update.
    ///   - englishText: The translated English text.
    /// - Returns: `true` if the block was found and updated.
    public mutating func updateBlock(id: UUID, englishText: String) -> Bool {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return false }
        var updated = blocks[index]
        updated.englishText = englishText
        blocks[index] = updated
        return true
    }
    
    /// Removes all blocks from the specified index onwards.
    ///
    /// - Parameter fromIndex: The starting index to remove from.
    public mutating func removeBlocks(fromIndex: Int) {
        guard fromIndex >= 0 && fromIndex < blocks.count else { return }
        blocks.removeSubrange(fromIndex...)
    }
    
    /// Removes all pause markers from the specified index onwards.
    ///
    /// - Parameter fromIndex: The starting index to remove from.
    public mutating func removePauseMarkers(fromIndex: Int) {
        guard fromIndex >= 0 && fromIndex < pauseMarkers.count else { return }
        pauseMarkers.removeSubrange(fromIndex...)
    }
    
    /// Clears all blocks and pause markers from the session.
    public mutating func clearAll() {
        blocks.removeAll()
        pauseMarkers.removeAll()
    }
}
