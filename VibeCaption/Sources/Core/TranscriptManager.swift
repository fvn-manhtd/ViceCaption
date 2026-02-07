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

/// Source of session-ending save events.
public enum TranscriptSessionEndTrigger: String {
    case manualStop
    case appQuit
    case overlayHidden
    case pipelineError
    case replacedByNewSession
    case periodicAutosave
}

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

    /// Autosave cadence in seconds for long-running sessions.
    private let autosaveInterval: TimeInterval

    /// Tracks whether session data changed since last save/autosave.
    private var hasPendingAutosaveChanges: Bool = false

    /// Timestamp of the last successful autosave.
    private var lastAutosaveDate: Date?

    /// Callback invoked when automatic save fails.
    public var onSaveFailure: ((TranscriptManagerError) -> Void)?
    
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

    /// Returns `true` if the current session has transcript blocks to persist.
    public var hasSavableContent: Bool {
        guard let session = currentSession else { return false }
        return !session.blocks.isEmpty
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
        fileManager: FileManager = .default,
        autosaveInterval: TimeInterval = 30
    ) {
        self.settingsManager = settingsManager
        self.formatter = formatter
        self.fileManager = fileManager
        self.autosaveInterval = autosaveInterval
        logger.debug("TranscriptManager initialized")
    }
    
    // MARK: - Session Management
    
    /// Starts a new transcript session.
    ///
    /// If there is an existing session, it will be ended before starting the new one.
    public func startNewSession() {
        if hasActiveSession {
            _ = endCurrentSession(trigger: .replacedByNewSession)
        }
        
        currentSession = TranscriptSession()
        displayStartIndex = 0
        pauseDisplayStartIndex = 0
        hasPendingAutosaveChanges = false
        lastAutosaveDate = nil
        logger.info("New transcript session started")
    }
    
    /// Ends the current session.
    @discardableResult
    public func endCurrentSession(trigger: TranscriptSessionEndTrigger = .manualStop) -> URL? {
        guard currentSession != nil else {
            logger.debug("No active session to end")
            return nil
        }

        if hasActiveSession {
            currentSession?.endSession()
            logger.info("Transcript session ended")
        }

        return persistCurrentSessionIfNeeded(trigger: trigger)
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
        markSessionChanged()
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
            markSessionChanged()
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
        markSessionChanged()
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
        markSessionChanged()
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
        markSessionChanged()
        
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

        guard !session.blocks.isEmpty else {
            logger.info("Skipping save for empty session")
            throw TranscriptManagerError.emptySession
        }

        let fileURL = try finalFileURL(for: session)
        try write(session: session, to: fileURL)
        try removeAutosaveFileIfPresent(for: session)

        hasPendingAutosaveChanges = false
        lastAutosaveDate = Date()
        logger.info("Session saved to: \(fileURL.path)")
        return fileURL
    }
    
    /// Returns the expected file URL for the current session without saving.
    ///
    /// - Returns: The expected file URL, or nil if there is no session.
    public func expectedFileURL() -> URL? {
        guard let session = currentSession else { return nil }

        do {
            return try finalFileURL(for: session)
        } catch {
            logger.error("Failed to compute expected file URL: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Private Methods

    private func markSessionChanged() {
        hasPendingAutosaveChanges = true
        maybeAutosave()
    }

    private func maybeAutosave() {
        guard autosaveInterval > 0 else { return }
        guard hasPendingAutosaveChanges else { return }
        guard let session = currentSession, session.isActive else { return }

        let now = Date()
        if let lastAutosaveDate, now.timeIntervalSince(lastAutosaveDate) < autosaveInterval {
            return
        }

        do {
            try writeAutosave(for: session)
            hasPendingAutosaveChanges = false
            lastAutosaveDate = now
            logger.debug("Periodic autosave completed")
        } catch {
            handleAutomaticSaveFailure(error, trigger: .periodicAutosave)
        }
    }

    private func persistCurrentSessionIfNeeded(trigger: TranscriptSessionEndTrigger) -> URL? {
        guard let session = currentSession else { return nil }

        if session.blocks.isEmpty {
            do {
                try removeAutosaveFileIfPresent(for: session)
            } catch {
                logger.error("Failed to clean autosave file: \(error.localizedDescription)")
            }
            logger.info("Skipping transcript save for empty session")
            return nil
        }

        do {
            let savedURL = try saveSession()
            logger.info("Session saved after trigger: \(trigger.rawValue)")
            return savedURL
        } catch {
            handleAutomaticSaveFailure(error, trigger: trigger)
            return nil
        }
    }

    private func writeAutosave(for session: TranscriptSession) throws {
        guard !session.blocks.isEmpty else {
            try removeAutosaveFileIfPresent(for: session)
            return
        }

        let autosaveURL = try autosaveFileURL(for: session)
        try write(session: session, to: autosaveURL)
    }

    private func write(session: TranscriptSession, to url: URL) throws {
        let content = formatter.formatForFile(session: session)

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw asTranscriptError(error, path: url.path)
        }
    }

    private func transcriptDirectoryURL() throws -> URL {
        let storagePath = settingsManager.transcriptStoragePath
        let expandedPath = (storagePath as NSString).expandingTildeInPath
        let directoryURL = URL(fileURLWithPath: expandedPath, isDirectory: true)

        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else {
                throw TranscriptManagerError.saveFailed(
                    underlyingError: NSError(
                        domain: NSCocoaErrorDomain,
                        code: NSFileWriteUnsupportedSchemeError,
                        userInfo: [NSLocalizedDescriptionKey: "Transcript storage path is not a directory"]
                    )
                )
            }
            return directoryURL
        }

        do {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            return directoryURL
        } catch {
            throw asTranscriptError(error, path: expandedPath)
        }
    }

    private func finalFileURL(for session: TranscriptSession) throws -> URL {
        let directoryURL = try transcriptDirectoryURL()
        let filename = formatter.generateFilename(for: session)
        return directoryURL.appendingPathComponent(filename, isDirectory: false)
    }

    private func autosaveFileURL(for session: TranscriptSession) throws -> URL {
        let directoryURL = try transcriptDirectoryURL()
        let filename = formatter.generateFilename(for: session)
        return directoryURL.appendingPathComponent("\(filename).autosave", isDirectory: false)
    }

    private func removeAutosaveFileIfPresent(for session: TranscriptSession) throws {
        let url = try autosaveFileURL(for: session)
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw asTranscriptError(error, path: url.path)
        }
    }

    private func asTranscriptError(_ error: Error, path: String? = nil) -> TranscriptManagerError {
        if let transcriptError = error as? TranscriptManagerError {
            return transcriptError
        }

        if let cocoaError = error as? CocoaError, cocoaError.code == .fileWriteOutOfSpace {
            return .diskFull(path: path)
        }

        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileWriteOutOfSpaceError {
            return .diskFull(path: path)
        }

        return .saveFailed(underlyingError: error)
    }

    private func handleAutomaticSaveFailure(_ error: Error, trigger: TranscriptSessionEndTrigger) {
        let transcriptError = asTranscriptError(error)
        logger.error("Automatic save failed (\(trigger.rawValue)): \(transcriptError.localizedDescription)")
        onSaveFailure?(transcriptError)
    }
}

// MARK: - TranscriptManagerError

/// Errors that can occur during transcript management.
public enum TranscriptManagerError: LocalizedError {
    /// No active session exists.
    case noActiveSession

    /// Session has no transcript blocks to save.
    case emptySession

    /// Disk is full while writing transcript data.
    case diskFull(path: String?)
    
    /// Failed to save the session to a file.
    case saveFailed(underlyingError: Error)
    
    public var errorDescription: String? {
        switch self {
        case .noActiveSession:
            return "No active transcript session"
        case .emptySession:
            return "Transcript session is empty, nothing to save"
        case .diskFull(let path):
            if let path {
                return "Disk is full. Could not save transcript to \(path)"
            }
            return "Disk is full. Could not save transcript"
        case .saveFailed(let error):
            return "Failed to save transcript: \(error.localizedDescription)"
        }
    }
}
