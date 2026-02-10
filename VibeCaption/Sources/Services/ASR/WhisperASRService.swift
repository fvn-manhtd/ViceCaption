import Foundation
import os.log
#if canImport(SwiftWhisper)
import SwiftWhisper
#endif

enum WhisperASRError: Error, LocalizedError {
    case modelNotLoaded
    case initializationFailed
    case backendUnavailable
    case transcriptionTimedOut

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Whisper model is not loaded."
        case .initializationFailed:
            return "Failed to initialize Whisper runtime."
        case .backendUnavailable:
            return "SwiftWhisper is not linked. Add the SwiftWhisper package to enable Whisper transcription."
        case .transcriptionTimedOut:
            return "Whisper transcription timed out."
        }
    }
}

#if canImport(SwiftWhisper)
final class WhisperASRService: ASRServiceProtocol {
    private let modelManager: ModelManager
    private var whisper: Whisper?
    private let logger: Logger

    private(set) var isModelLoaded: Bool = false

    init(modelManager: ModelManager) {
        self.modelManager = modelManager
        self.logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "com.vibecaption",
            category: "WhisperASRService"
        )
    }

    func loadModel() async throws {
        guard !isModelLoaded else { return }

        guard let modelID = modelManager.getASRModelID(),
              let modelInfo = modelManager.getModel(id: modelID) else {
            throw ModelError.modelNotFound("Preferred Whisper model")
        }

        guard let modelPath = modelManager.getModelPath(for: modelInfo) else {
            throw ModelError.invalidInstallation
        }

        let resolvedModelURL = try resolveWhisperModelURL(basePath: modelPath, modelInfo: modelInfo)
        logger.info("Loading Whisper model from: \(resolvedModelURL.path)")

        let whisperInstance = Whisper(fromFileURL: resolvedModelURL)

        whisperInstance.params.language = .japanese
        whisperInstance.params.print_realtime = false
        whisperInstance.params.print_progress = false
        whisperInstance.params.translate = false

        whisper = whisperInstance
        isModelLoaded = true
        logger.info("Whisper model loaded successfully")
    }

    func unloadModel() {
        whisper = nil
        isModelLoaded = false
        logger.info("Whisper model unloaded")
    }

    func transcribe(_ audio: AudioSegment) async throws -> ASRResult {
        guard let whisper, isModelLoaded else {
            throw WhisperASRError.modelNotLoaded
        }

        guard !audio.audioData.isEmpty else {
            return ASRResult(segments: [], processingTime: 0)
        }

        logger.debug("Starting transcription on \(audio.audioData.count) samples")

        let startedAt = Date()
        let segments = try await whisper.transcribe(audioFrames: audio.audioData)
        let mappedSegments = segments.map { segment -> ASRSegment in
            let startSeconds = TimeInterval(segment.startTime) / 1000.0
            let endSeconds = TimeInterval(segment.endTime) / 1000.0
            return ASRSegment(
                text: segment.text,
                startTime: audio.startTime + startSeconds,
                endTime: audio.startTime + endSeconds,
                speakerID: nil,
                confidence: 1.0
            )
        }

        return ASRResult(
            segments: mappedSegments,
            processingTime: Date().timeIntervalSince(startedAt)
        )
    }

    private func resolveWhisperModelURL(basePath: URL, modelInfo: ModelInfo) throws -> URL {
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: basePath.path) {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: basePath.path, isDirectory: &isDirectory), !isDirectory.boolValue {
                return basePath
            }

            let primaryFilename = modelInfo.downloadURL.lastPathComponent
            if !primaryFilename.isEmpty {
                let primaryCandidate = basePath.appendingPathComponent(primaryFilename)
                if fileManager.fileExists(atPath: primaryCandidate.path) {
                    return primaryCandidate
                }
            }

            let fallbackCandidates = try fileManager.contentsOfDirectory(
                at: basePath,
                includingPropertiesForKeys: nil
            ).filter {
                $0.pathExtension == "bin" || $0.lastPathComponent.hasPrefix("ggml-")
            }

            if let firstCandidate = fallbackCandidates.first {
                return firstCandidate
            }
        }

        throw ModelError.modelNotFound(modelInfo.id)
    }
}
#else
final class WhisperASRService: ASRServiceProtocol {
    private(set) var isModelLoaded: Bool = false

    init(modelManager: ModelManager) {
        _ = modelManager
    }

    func loadModel() async throws {
        throw WhisperASRError.backendUnavailable
    }

    func unloadModel() {
        isModelLoaded = false
    }

    func transcribe(_ audio: AudioSegment) async throws -> ASRResult {
        _ = audio
        throw WhisperASRError.backendUnavailable
    }
}
#endif
