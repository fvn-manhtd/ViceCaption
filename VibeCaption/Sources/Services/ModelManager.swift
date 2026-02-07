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

public struct ModelUpdate: Identifiable, Equatable {
    public let id: String
    public let currentModel: ModelInfo
    public let latestModel: ModelInfo

    public var currentVersion: String { currentModel.version }
    public var latestVersion: String { latestModel.version }

    public init(currentModel: ModelInfo, latestModel: ModelInfo) {
        self.id = currentModel.id
        self.currentModel = currentModel
        self.latestModel = latestModel
    }
}

// MARK: - ModelManager

public final class ModelManager: ObservableObject {
    
    // MARK: - Properties
    
    @Published public private(set) var models: [ModelInfo] = []
    @Published public private(set) var modelStatuses: [String: ModelStatus] = [:]
    @Published public private(set) var downloadProgress: [String: Double] = [:]
    @Published public private(set) var availableModelUpdates: [ModelUpdate] = []
    
    private let settingsManager: SettingsManager
    private let fileManager = FileManager.default
    private let session: URLSession
    
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var progressObservers: [String: NSKeyValueObservation] = [:]
    private var latestCatalogByModelID: [String: ModelInfo] = [:]
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
            self.latestCatalogByModelID = [:]
            self.availableModelUpdates = []
            
            // Initialize statuses based on file existence
            for model in catalog {
                updateStatus(for: model)
            }
            
            logger.info("Loaded \(self.models.count) models from catalog")
        } catch {
            logger.error("Failed to load model catalog: \(error.localizedDescription)")
        }
    }

    /// Checks remote catalog for model updates. This is user-triggered from Settings and not automatic.
    @discardableResult
    public func checkForModelUpdates(catalogURL: URL?) async throws -> [ModelUpdate] {
        guard let catalogURL else {
            DispatchQueue.main.async {
                self.availableModelUpdates = []
            }
            return []
        }

        if models.isEmpty {
            loadModelCatalog()
        }

        let latestCatalog = try await loadCatalog(from: catalogURL)
        let updates = Self.detectModelUpdates(
            currentCatalog: models,
            latestCatalog: latestCatalog,
            installedStatuses: modelStatuses
        )

        DispatchQueue.main.async {
            self.latestCatalogByModelID = Dictionary(uniqueKeysWithValues: latestCatalog.map { ($0.id, $0) })
            self.availableModelUpdates = updates

            for update in updates {
                if let existingIndex = self.models.firstIndex(where: { $0.id == update.id }) {
                    self.models[existingIndex] = update.latestModel
                } else {
                    self.models.append(update.latestModel)
                }
                self.modelStatuses[update.id] = .updateAvailable
            }
        }

        logger.info("Model update check complete: \(updates.count) updates available")
        return updates
    }

    /// Returns the latest known model metadata for an ID, preferring remote catalog info if available.
    public func latestModelInfo(for modelID: String) -> ModelInfo? {
        latestCatalogByModelID[modelID] ?? getModel(id: modelID)
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
                         self.progressObservers.removeValue(forKey: model.id)
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

                 if let httpResponse = response as? HTTPURLResponse,
                    !(200...299).contains(httpResponse.statusCode) {
                     DispatchQueue.main.async {
                         self.modelStatuses[model.id] = .notDownloaded
                     }
                     let statusError = NSError(
                         domain: "ModelManager",
                         code: httpResponse.statusCode,
                         userInfo: [NSLocalizedDescriptionKey: "Model download failed with HTTP \(httpResponse.statusCode)"]
                     )
                     continuation.resume(throwing: ModelError.downloadFailed(statusError))
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
                             self.availableModelUpdates.removeAll { $0.id == model.id }
                             self.latestCatalogByModelID[model.id] = model
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
             
             // Keep observation token alive for the full download lifecycle.
             self.progressObservers[model.id] = progressObserver
             self.downloadTasks[model.id] = task
             task.resume()
         }
    }
    
    // MARK: - Verification
    
    public func verifyModel(_ model: ModelInfo) -> Bool {
        guard let destination = getDownloadDestination(for: model),
              fileManager.fileExists(atPath: destination.path) else {
            return false
        }

        guard validateDownloadedFile(at: destination, modelID: model.id) else {
            return false
        }

        let normalizedChecksum = model.checksum
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard let algorithm = checksumAlgorithm(for: normalizedChecksum) else {
            logger.warning("Skipping checksum for \(model.id); checksum missing or unsupported in catalog")
            return true
        }
        
        do {
            let fileData = try Data(contentsOf: destination, options: .mappedIfSafe)
            let calculatedChecksum = hashDigest(for: fileData, algorithm: algorithm)
            
            let matches = calculatedChecksum.caseInsensitiveCompare(normalizedChecksum) == .orderedSame
            if !matches {
                logger.error("Checksum mismatch for \(model.id). Expected: \(normalizedChecksum), Got: \(calculatedChecksum)")
            }
            return matches
        } catch {
            logger.error("Error verifying model \(model.id): \(error.localizedDescription)")
            return false
        }
    }

    private func validateDownloadedFile(at url: URL, modelID: String) -> Bool {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            if fileSize <= 0 {
                logger.error("Downloaded model file is empty for \(modelID)")
                return false
            }

            let prefix = try readPrefix(from: url, byteCount: 512)
            if looksLikeHTML(prefix) {
                logger.error("Downloaded payload for \(modelID) looks like an HTML error page")
                return false
            }

            return true
        } catch {
            logger.error("Failed to validate downloaded model file for \(modelID): \(error.localizedDescription)")
            return false
        }
    }

    private func readPrefix(from url: URL, byteCount: Int) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        return try handle.read(upToCount: byteCount) ?? Data()
    }

    private func looksLikeHTML(_ data: Data) -> Bool {
        guard !data.isEmpty else { return false }
        let snippet = String(decoding: data, as: UTF8.self).lowercased()
        return snippet.contains("<html") || snippet.contains("<!doctype html")
    }

    private func hashDigest(for data: Data, algorithm: ChecksumAlgorithm) -> String {
        switch algorithm {
        case .sha256:
            let digest = SHA256.hash(data: data)
            return digest.compactMap { String(format: "%02x", $0) }.joined()
        case .sha1:
            let digest = Insecure.SHA1.hash(data: data)
            return digest.compactMap { String(format: "%02x", $0) }.joined()
        case .md5:
            let digest = Insecure.MD5.hash(data: data)
            return digest.compactMap { String(format: "%02x", $0) }.joined()
        }
    }

    private func checksumAlgorithm(for checksum: String) -> ChecksumAlgorithm? {
        guard !checksum.isEmpty else { return nil }
        guard checksum != Self.emptySHA256Checksum &&
                checksum != Self.emptySHA1Checksum &&
                checksum != Self.emptyMD5Checksum else {
            return nil
        }
        guard checksum.range(of: "^[0-9a-f]+$", options: .regularExpression) != nil else {
            return nil
        }

        switch checksum.count {
        case 64: return .sha256
        case 40: return .sha1
        case 32: return .md5
        default: return nil
        }
    }

    private enum ChecksumAlgorithm {
        case sha256
        case sha1
        case md5
    }

    private static let emptySHA256Checksum = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    private static let emptySHA1Checksum = "da39a3ee5e6b4b0d3255bfef95601890afd80709"
    private static let emptyMD5Checksum = "d41d8cd98f00b204e9800998ecf8427e"
    
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

    // MARK: - Update Helpers

    static func detectModelUpdates(
        currentCatalog: [ModelInfo],
        latestCatalog: [ModelInfo],
        installedStatuses: [String: ModelStatus]
    ) -> [ModelUpdate] {
        let latestByID = Dictionary(uniqueKeysWithValues: latestCatalog.map { ($0.id, $0) })
        return currentCatalog.compactMap { currentModel in
            guard installedStatuses[currentModel.id] == .downloaded else {
                return nil
            }
            guard let latestModel = latestByID[currentModel.id] else {
                return nil
            }
            guard compareVersions(latestModel.version, currentModel.version) == .orderedDescending else {
                return nil
            }
            return ModelUpdate(currentModel: currentModel, latestModel: latestModel)
        }
    }

    static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let lhsComponents = normalizedVersionComponents(from: lhs)
        let rhsComponents = normalizedVersionComponents(from: rhs)
        let maxCount = max(lhsComponents.count, rhsComponents.count)

        for index in 0..<maxCount {
            let lhsComponent = index < lhsComponents.count ? lhsComponents[index] : .numeric(0)
            let rhsComponent = index < rhsComponents.count ? rhsComponents[index] : .numeric(0)

            switch (lhsComponent, rhsComponent) {
            case let (.numeric(lhsValue), .numeric(rhsValue)):
                if lhsValue < rhsValue { return .orderedAscending }
                if lhsValue > rhsValue { return .orderedDescending }
            case let (.text(lhsValue), .text(rhsValue)):
                let comparison = lhsValue.localizedStandardCompare(rhsValue)
                if comparison != .orderedSame { return comparison }
            case (.numeric, .text):
                return .orderedDescending
            case (.text, .numeric):
                return .orderedAscending
            }
        }

        return .orderedSame
    }

    private static func normalizedVersionComponents(from version: String) -> [VersionComponent] {
        version
            .split(whereSeparator: { $0 == "." || $0 == "-" || $0 == "_" })
            .map { component in
                if let numericValue = Int(component) {
                    return .numeric(numericValue)
                }
                return .text(component.lowercased())
            }
    }

    private enum VersionComponent {
        case numeric(Int)
        case text(String)
    }

    private func loadCatalog(from url: URL) async throws -> [ModelInfo] {
        let data: Data
        if url.isFileURL {
            data = try Data(contentsOf: url)
        } else {
            let (responseData, _) = try await session.data(from: url)
            data = responseData
        }
        return try JSONDecoder().decode([ModelInfo].self, from: data)
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
