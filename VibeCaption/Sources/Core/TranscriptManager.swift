//
//  TranscriptManager.swift
//  VibeCaption
//
//  Manages transcript sessions, including storage, display state, and file saving.
//

import Foundation
import Combine
import os.log

// MARK: - TranscriptManager

/// Manages transcript sessions and their persistence.
///
/// The TranscriptManager handles:
/// - Creating and managing the current transcript session
/// - Adding blocks and pause markers
/// - Managing display state (clear display vs clear and discard)
/// - Saving sessions to files
///
/// Example:
/// ```swift
/// let manager = TranscriptManager(settingsManager: settingsManager)
/// manager.startNewSession()
/// manager.addBlock(block)
/// try manager.saveSession()
/// ```
public final class TranscriptManager: ObservableObject {
    
    // MARK: - Properties
    
    /// The current active transcript session.
    @Published public private(set) var currentSession: TranscriptSession?
    
    /// Index of the first block to display (for clearDisplay functionality).
    @Published public private(set) var displayStartIndex: Int = 0
    
    /// Index of the first pause marker to display.
    @Published public private(set) var pauseDisplayStartIndex: Int = 0
    
    /// The settings manager for configuration.
    private let settingsManager: SettingsManager
    
    /// The transcript formatter.
    private let formatter: TranscriptFormatter
    
    /// Logger for debugging.
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.yourcompany.vibecaption",
        category: "TranscriptManager"
    )
    
    /// File manager for file operations.
    private let fileManager: FileManager
    
    // MARK: - Computed Properties
    
    /// Returns the blocks that should be displayed (after clearDisplay).
    public var displayableBlocks: [TranscriptBlock] {
        guard let session = currentSession else { return [] }
        guard displayStartIndex < session.blocks.count else { return [] }
        return Array(session.blocks[displayStartIndex...])
    }
    
    /// Returns the pause markers that should be displayed.
    public var displayablePauseMarkers: [PauseMarker] {
        guard let session = currentSession else { return [] }
        guard pauseDisplayStartIndex < session.pauseMarkers.count else { return [] }
        return Array(session.pauseMarkers[pauseDisplayStartIndex...])
    }
    
    /// Returns `true` if there is an active session.
    public var hasActiveSession: Bool {
        currentSession?.isActive ?? false
    }
    
    // MARK: - Initialization
    
    /// Creates a new transcript manager.
    ///
    /// - Parameters:
    ///   - settingsManager: The settings manager for configuration.
    ///   - formatter: Optional custom formatter. Defaults to a new instance.
    ///   - fileManager: Optional custom file manager. Defaults to `.default`.
    public init(
        settingsManager: SettingsManager,
        formatter: TranscriptFormatter = TranscriptFormatter(),
        fileManager: FileManager = .default
    ) {
        self.settingsManager = settingsManager
        self.formatter = formatter
        self.fileManager = fileManager
        logger.debug("TranscriptManager initialized")
    }
    
    // MARK: - Session Management
    
    /// Starts a new transcript session.
    ///
    /// If there is an existing session, it will be ended before starting the new one.
    public func startNewSession() {
        if currentSession != nil {
            endCurrentSession()
        }
        
        currentSession = TranscriptSession()
        displayStartIndex = 0
        pauseDisplayStartIndex = 0
        logger.info("New transcript session started")
    }
    
    /// Ends the current session.
    public func endCurrentSession() {
        currentSession?.endSession()
        logger.info("Transcript session ended")
    }
    
    // MARK: - Block Management
    
    /// Adds a transcript block to the current session.
    ///
    /// - Parameter block: The block to add.
    /// - Note: Does nothing if there is no active session.
    public func addBlock(_ block: TranscriptBlock) {
        guard currentSession != nil else {
            logger.warning("Cannot add block: no active session")
            return
        }
        
        currentSession?.addBlock(block)
        logger.debug("Added transcript block: \(block.japaneseText.prefix(20))...")
    }

    /// Updates a transcript block with translated English text.
    ///
    /// - Parameters:
    ///   - id: The identifier of the block to update.
    ///   - englishText: The translated English text.
    /// - Returns: `true` if the block was found and updated.
    @discardableResult
    public func updateBlock(id: UUID, englishText: String) -> Bool {
        guard var session = currentSession else {
            logger.warning("Cannot update block: no active session")
            return false
        }

        let updated = session.updateBlock(id: id, englishText: englishText)
        if updated {
            currentSession = session
            logger.debug("Updated transcript block with translation: \(id.uuidString)")
        }

        return updated
    }
    
    /// Adds a pause marker to the current session with the current timestamp.
    ///
    /// - Note: Does nothing if there is no active session.
    public func addPauseMarker() {
        guard currentSession != nil else {
            logger.warning("Cannot add pause marker: no active session")
            return
        }
        
        let marker = PauseMarker()
        currentSession?.addPauseMarker(marker)
        logger.debug("Added pause marker at \(marker.timestamp)")
    }
    
    /// Adds a pause marker with a specific timestamp.
    ///
    /// - Parameter marker: The pause marker to add.
    public func addPauseMarker(_ marker: PauseMarker) {
        guard currentSession != nil else {
            logger.warning("Cannot add pause marker: no active session")
            return
        }
        
        currentSession?.addPauseMarker(marker)
        logger.debug("Added pause marker at \(marker.timestamp)")
    }
    
    // MARK: - Clear Operations
    
    /// Clears the display but keeps all data for file saving.
    ///
    /// This updates the display indices so that displayed blocks appear cleared,
    /// but the underlying data is preserved for the saved transcript file.
    public func clearDisplay() {
        guard let session = currentSession else { return }
        
        displayStartIndex = session.blocks.count
        pauseDisplayStartIndex = session.pauseMarkers.count
        logger.info("Display cleared (data preserved)")
    }
    
    /// Clears the display and permanently discards the cleared data.
    ///
    /// This removes the currently hidden blocks and pause markers from the session.
    /// The data cannot be recovered after this operation.
    public func clearAndDiscard() {
        guard currentSession != nil else { return }
        
        // Remove hidden content
        currentSession?.removeBlocks(fromIndex: 0)
        currentSession?.removePauseMarkers(fromIndex: 0)
        
        // Reset display indices
        displayStartIndex = 0
        pauseDisplayStartIndex = 0
        
        logger.info("Display cleared and data discarded")
    }
    
    // MARK: - File Operations
    
    /// Saves the current session to a file.
    ///
    /// - Returns: The URL of the saved file.
    /// - Throws: An error if there is no session or if saving fails.
    @discardableResult
    public func saveSession() throws -> URL {
        guard let session = currentSession else {
            logger.error("Cannot save: no active session")
            throw TranscriptManagerError.noActiveSession
        }
        
        // Get the storage path from settings
        let storagePath = settingsManager.transcriptStoragePath
        let expandedPath = (storagePath as NSString).expandingTildeInPath
        
        // Ensure directory exists
        if !fileManager.fileExists(atPath: expandedPath) {
            try fileManager.createDirectory(
                atPath: expandedPath,
                withIntermediateDirectories: true
            )
        }
        
        // Generate filename and full path
        let filename = formatter.generateFilename(for: session)
        let fileURL = URL(fileURLWithPath: expandedPath).appendingPathComponent(filename)
        
        // Format session content
        let content = formatter.formatForFile(session: session)
        
        // Write to file
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        
        logger.info("Session saved to: \(fileURL.path)")
        return fileURL
    }
    
    /// Returns the expected file URL for the current session without saving.
    ///
    /// - Returns: The expected file URL, or nil if there is no session.
    public func expectedFileURL() -> URL? {
        guard let session = currentSession else { return nil }
        
        let storagePath = settingsManager.transcriptStoragePath
        let expandedPath = (storagePath as NSString).expandingTildeInPath
        let filename = formatter.generateFilename(for: session)
        
        return URL(fileURLWithPath: expandedPath).appendingPathComponent(filename)
    }
}

// MARK: - TranscriptManagerError

/// Errors that can occur during transcript management.
public enum TranscriptManagerError: LocalizedError {
    /// No active session exists.
    case noActiveSession
    
    /// Failed to save the session to a file.
    case saveFailed(underlyingError: Error)
    
    public var errorDescription: String? {
        switch self {
        case .noActiveSession:
            return "No active transcript session"
        case .saveFailed(let error):
            return "Failed to save transcript: \(error.localizedDescription)"
        }
    }
}
