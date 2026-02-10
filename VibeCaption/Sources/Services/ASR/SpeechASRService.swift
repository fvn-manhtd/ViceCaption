import AVFoundation
import Foundation
import Speech
import os.log

// MARK: - Errors

enum SpeechASRError: Error, LocalizedError {
    case notAuthorized
    case recognizerUnavailable
    case audioEncodingFailed
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition permission was not granted."
        case .recognizerUnavailable:
            return "Speech recognizer is not available for Japanese."
        case .audioEncodingFailed:
            return "Failed to prepare audio buffer for speech recognition."
        case .recognitionFailed(let detail):
            return "Speech recognition failed: \(detail)"
        }
    }
}

// MARK: - SpeechASRService

/// ASR service implementation using Apple's Speech framework (SFSpeechRecognizer).
///
/// Converts each `AudioSegment` into an `SFSpeechAudioBufferRecognitionRequest`,
/// feeds the PCM samples, and returns the final transcription as an `ASRResult`.
///
/// Key characteristics:
/// - On-device recognition (no network required)
/// - Japanese locale (`ja-JP`)
/// - Low latency compared to Whisper for short segments
final class SpeechASRService: ASRServiceProtocol {

    // MARK: - Properties

    private let recognizerLocale = Locale(identifier: "ja-JP")
    private var recognizer: SFSpeechRecognizer?
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.vibecaption",
        category: "SpeechASRService"
    )

    private(set) var isModelLoaded: Bool = false

    /// The audio format used for feeding buffers to Speech framework.
    /// Must match the format of AudioSegment data (16kHz, mono, Float32).
    private let audioFormat: AVAudioFormat? = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16_000,
        channels: 1,
        interleaved: false
    )

    // MARK: - ASRServiceProtocol

    func loadModel() async throws {
        // 1. Request authorization
        let status = await requestAuthorization()
        guard status == .authorized else {
            logger.error("Speech recognition not authorized. Status: \(status.rawValue)")
            throw SpeechASRError.notAuthorized
        }

        // 2. Create recognizer for Japanese
        guard let rec = SFSpeechRecognizer(locale: recognizerLocale) else {
            throw SpeechASRError.recognizerUnavailable
        }

        // 3. Prefer on-device recognition for low latency
        if rec.supportsOnDeviceRecognition {
            rec.defaultTaskHint = .dictation
            logger.info("On-device speech recognition is available for ja-JP")
        } else {
            logger.warning("On-device recognition not available; will use server-based")
        }

        guard rec.isAvailable else {
            throw SpeechASRError.recognizerUnavailable
        }

        recognizer = rec
        isModelLoaded = true
        logger.info("SpeechASRService loaded successfully")
    }

    func unloadModel() {
        recognizer = nil
        isModelLoaded = false
        logger.info("SpeechASRService unloaded")
    }

    func transcribe(_ audio: AudioSegment) async throws -> ASRResult {
        guard let recognizer, isModelLoaded else {
            throw SpeechASRError.recognizerUnavailable
        }

        guard !audio.audioData.isEmpty else {
            return ASRResult(segments: [], processingTime: 0)
        }

        let startedAt = Date()

        // Create a buffer recognition request (streaming-capable)
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = false
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        // Feed the audio segment as a PCM buffer
        try feedAudioToRequest(audio, request: request)

        // Perform recognition
        let result = try await performRecognition(recognizer: recognizer, request: request)

        let text = result.bestTranscription.formattedString
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let processingTime = Date().timeIntervalSince(startedAt)

        guard !text.isEmpty else {
            return ASRResult(segments: [], processingTime: processingTime)
        }

        // Compute average confidence from transcription segments
        let transcriptionSegments = result.bestTranscription.segments
        let avgConfidence: Double
        if transcriptionSegments.isEmpty {
            avgConfidence = 0.7
        } else {
            let total = transcriptionSegments.reduce(0.0) { $0 + Double($1.confidence) }
            avgConfidence = min(1.0, max(0.0, total / Double(transcriptionSegments.count)))
        }

        logger.debug("Recognized text: \(text) (confidence: \(avgConfidence))")

        let segment = ASRSegment(
            text: text,
            startTime: audio.startTime,
            endTime: audio.endTime,
            speakerID: nil,
            confidence: avgConfidence
        )

        return ASRResult(
            segments: [segment],
            processingTime: processingTime
        )
    }

    // MARK: - Private Helpers

    /// Requests speech recognition authorization.
    private func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        let currentStatus = SFSpeechRecognizer.authorizationStatus()
        guard currentStatus == .notDetermined else {
            return currentStatus
        }

        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    /// Converts an `AudioSegment` into a PCM buffer and appends it to the recognition request.
    private func feedAudioToRequest(
        _ audio: AudioSegment,
        request: SFSpeechAudioBufferRecognitionRequest
    ) throws {
        guard let format = audioFormat else {
            throw SpeechASRError.audioEncodingFailed
        }

        let frameCount = AVAudioFrameCount(audio.audioData.count)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channelData = buffer.floatChannelData?.pointee else {
            throw SpeechASRError.audioEncodingFailed
        }

        buffer.frameLength = frameCount
        audio.audioData.withUnsafeBufferPointer { srcPtr in
            guard let baseAddress = srcPtr.baseAddress else { return }
            channelData.update(from: baseAddress, count: Int(frameCount))
        }

        request.append(buffer)
        request.endAudio()
    }

    /// Runs the recognition task and returns the final result.
    private func performRecognition(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest
    ) async throws -> SFSpeechRecognitionResult {
        try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            var recognitionTask: SFSpeechRecognitionTask?

            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                if hasResumed { return }

                if let error {
                    hasResumed = true
                    recognitionTask?.cancel()
                    continuation.resume(
                        throwing: SpeechASRError.recognitionFailed(error.localizedDescription)
                    )
                    return
                }

                guard let result else { return }

                if result.isFinal {
                    hasResumed = true
                    continuation.resume(returning: result)
                }
            }
        }
    }
}
