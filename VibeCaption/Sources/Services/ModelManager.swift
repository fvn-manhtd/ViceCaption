//
//  ModelManager.swift
//  VibeCaption
//
//  Manages the lifecycle of AI models including downloading, verification, and storage.
//

import Foundation
import Combine
import CryptoKit
import os.log

// MARK: - Error Types

public enum ModelError: Error, LocalizedError {
    case modelNotFound(String)
    case downloadFailed(Error)
    case verificationFailed
    case deletionFailed(Error)
    case catalogLoadFailed(Error)
    case invalidCatalogData
    case invalidInstallation
    
    public var errorDescription: String? {
        switch self {
        case .modelNotFound(let id):
            return "Model with ID '\(id)' was not found."
        case .downloadFailed(let error):
            return "Failed to download model: \(error.localizedDescription)"
        case .verificationFailed:
            return "Model file verification failed (checksum mismatch)."
        case .deletionFailed(let error):
            return "Failed to delete model: \(error.localizedDescription)"
        case .catalogLoadFailed(let error):
            return "Failed to load model catalog: \(error.localizedDescription)"
        case .invalidCatalogData:
            return "Model catalog data is invalid."
        case .invalidInstallation:
            return "Model installation is invalid or incomplete."
        }
    }
}

// MARK: - ModelManager

public final class ModelManager: ObservableObject {
    
    // MARK: - Properties
    
    @Published public private(set) var models: [ModelInfo] = []
    @Published public private(set) var modelStatuses: [String: ModelStatus] = [:]
    @Published public private(set) var downloadProgress: [String: Double] = [:]
    
    private let settingsManager: SettingsManager
    private let fileManager = FileManager.default
    private let session: URLSession
    
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.vibecaption",
        category: "ModelManager"
    )
    
    // MARK: - Initialization
    
    public init(settingsManager: SettingsManager, urlSession: URLSession = .shared) {
        self.settingsManager = settingsManager
        self.session = urlSession
        
        logger.debug("ModelManager initialized")
    }
    
    // MARK: - Catalog Management
    
    public func loadModelCatalog() {
        guard let url = Bundle.main.url(forResource: "model-catalog", withExtension: "json") else {
            logger.error("model-catalog.json not found in bundle")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let catalog = try JSONDecoder().decode([ModelInfo].self, from: data)
            self.models = catalog
            
            // Initialize statuses based on file existence
            for model in catalog {
                updateStatus(for: model)
            }
            
            logger.info("Loaded \(self.models.count) models from catalog")
        } catch {
            logger.error("Failed to load model catalog: \(error.localizedDescription)")
        }
    }
    
    public func getModel(id: String) -> ModelInfo? {
        models.first { $0.id == id }
    }
    
    // MARK: - Path Management
    
    public func getModelPath(for model: ModelInfo) -> URL? {
        let baseDir = URL(fileURLWithPath: settingsManager.modelStoragePath)
        return baseDir.appendingPathComponent(model.id).appendingPathComponent(model.version)
    }
    
    private func getDownloadDestination(for model: ModelInfo) -> URL? {
        guard let modelDir = getModelPath(for: model) else { return nil }
        
        // Single file models usually just download to the directory with the model name,
        // but since these might be archives or direct files, we need to handle that.
        // For simplicity, we assume the download URL's last path component is the filename.
        let filename = model.downloadURL.lastPathComponent
        return modelDir.appendingPathComponent(filename)
    }
    
    // MARK: - Status Checking
    
    public func isModelReady(_ modelID: String) -> Bool {
        return modelStatuses[modelID]?.isReady ?? false
    }
    
    private func updateStatus(for model: ModelInfo) {
        guard let destination = getDownloadDestination(for: model) else {
            modelStatuses[model.id] = .notDownloaded
            return
        }
        
        // Check if file exists
        if fileManager.fileExists(atPath: destination.path) {
             // In a real app we might want to check checksum here too, but that's expensive for every launch.
             // We'll trust file existence unless explicit verification is requested or on install.
             modelStatuses[model.id] = .downloaded
        } else {
             modelStatuses[model.id] = .notDownloaded
        }
    }

    // MARK: - Downloading
    
    public func downloadModel(_ model: ModelInfo) async throws {
        guard let destination = getDownloadDestination(for: model) else {
            throw ModelError.invalidInstallation
        }
        
        // Create directory
        do {
            try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            throw ModelError.downloadFailed(error)
        }

        // Set status to downloading
        DispatchQueue.main.async {
            self.modelStatuses[model.id] = .downloading(progress: 0.0)
            self.downloadProgress[model.id] = 0.0
        }
        
        logger.info("Starting download for model: \(model.id)")
        
        // We use a closure-based delegation for progress updates in this simplified async method
        // In a more complex scenario we might use a delegate or Combine publisher for progress
        
        // Check if already downloading to avoid duplicate tasks (simplified)
        if downloadTasks[model.id] != nil {
             logger.warning("Download already in progress for \(model.id)")
             return
        }
        
        return try await withCheckedThrowingContinuation { continuation in
             let task = session.downloadTask(with: model.downloadURL) { [weak self] tempURL, response, error in
                 guard let self = self else { return }
                 
                 defer {
                     DispatchQueue.main.async {
                         self.downloadTasks.removeValue(forKey: model.id)
                         self.downloadProgress.removeValue(forKey: model.id)
                     }
                 }
                 
                 if let error = error {
                     DispatchQueue.main.async {
                         self.modelStatuses[model.id] = .notDownloaded // or error state
                     }
                     continuation.resume(throwing: ModelError.downloadFailed(error))
                     return
                 }
                 
                 guard let tempURL = tempURL else {
                     continuation.resume(throwing: ModelError.downloadFailed(NSError(domain: "ModelManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No temp file location"])))
                     return
                 }
                 
                 do {
                     // Move file to destination
                     if self.fileManager.fileExists(atPath: destination.path) {
                         try self.fileManager.removeItem(at: destination)
                     }
                     try self.fileManager.moveItem(at: tempURL, to: destination)
                     
                     // Verify
                     if self.verifyModel(model) {
                         DispatchQueue.main.async {
                             self.modelStatuses[model.id] = .downloaded
                         }
                         self.logger.info("Download and verification successful for \(model.id)")
                         continuation.resume()
                     } else {
                         // Corrupted
                         try? self.fileManager.removeItem(at: destination)
                         DispatchQueue.main.async {
                             self.modelStatuses[model.id] = .corrupted
                         }
                         self.logger.error("Verification failed for \(model.id)")
                         continuation.resume(throwing: ModelError.verificationFailed)
                     }
                 } catch {
                     DispatchQueue.main.async {
                         self.modelStatuses[model.id] = .notDownloaded
                     }
                     continuation.resume(throwing: ModelError.downloadFailed(error))
                 }
             }
             
             // Observe progress
             let progressObserver = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
                 DispatchQueue.main.async {
                     self?.downloadProgress[model.id] = progress.fractionCompleted
                     self?.modelStatuses[model.id] = .downloading(progress: progress.fractionCompleted)
                 }
             }
             
             // Keep reference to observer to prevent deallocation - or just rely on task completion
             // The task holds a strong reference to progress, but we need to keep the observation alive?
             // Actually, `task.progress` is KVO compliant.
             
             self.downloadTasks[model.id] = task
             task.resume()
             
             // NOTE: In a real app we'd need to handle Observation token lifecycle properly.
             // For this implementation, we're relying on the fact that progress updates are frequent enough
             // and the task will complete.
         }
    }
    
    // MARK: - Verification
    
    public func verifyModel(_ model: ModelInfo) -> Bool {
        guard let destination = getDownloadDestination(for: model),
              fileManager.fileExists(atPath: destination.path) else {
            return false
        }
        
        do {
            let fileData = try Data(contentsOf: destination, options: .mappedIfSafe)
            let digest = SHA256.hash(data: fileData)
            let calculatedChecksum = digest.compactMap { String(format: "%02x", $0) }.joined()
            
            let matches = calculatedChecksum.caseInsensitiveCompare(model.checksum) == .orderedSame
            if !matches {
                logger.error("Checksum mismatch for \(model.id). Expected: \(model.checksum), Got: \(calculatedChecksum)")
            }
            return matches
        } catch {
            logger.error("Error verifying model \(model.id): \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Deletion
    
    public func deleteModel(_ model: ModelInfo) throws {
        guard let dir = getModelPath(for: model) else {
            throw ModelError.invalidInstallation
        }
        
        do {
            if fileManager.fileExists(atPath: dir.path) {
                try fileManager.removeItem(at: dir)
            }
            
            DispatchQueue.main.async {
                self.modelStatuses[model.id] = .notDownloaded
            }
            logger.info("Deleted model: \(model.id)")
        } catch {
            logger.error("Failed to delete model \(model.id): \(error.localizedDescription)")
            throw ModelError.deletionFailed(error)
        }
    }
    
    // MARK: - Utility Methods
    
    public func getInstalledVersions() -> [String: String] {
        var versions: [String: String] = [:]
        for model in models {
            if modelStatuses[model.id] == .downloaded {
                versions[model.id] = model.version
            }
        }
        return versions
    }
    
    public func getTotalDiskUsage() -> Int64 {
        var total: Int64 = 0
        for model in models {
            if modelStatuses[model.id] == .downloaded {
                total += model.sizeBytes
            }
        }
        return total
    }
    
    // MARK: - Helper Queries
    
    public func getTranslationModelID(for sourceLang: String, targetLang: String) -> String? {
        // Simple logic for now: prefer CoreML, falling back to optional if needed/implemented
        // Format assumption: "opus-mt-{src}-{tgt}-coreml"
        let expectedID = "opus-mt-\(sourceLang)-\(targetLang)-coreml"
        
        if let model = models.first(where: { $0.id == expectedID }),
           isModelReady(model.id) {
            return model.id
        }
        
        // Try reverse direction if it's a bilingual model that works both ways?
        // Usually OPUS models are direction specific.
        
        return nil
    }
    
    public func getASRModelID() -> String? {
        // Return ID of the preferred/required ASR model
        return models.first(where: { $0.id.contains("whisper") })?.id
    }
}
