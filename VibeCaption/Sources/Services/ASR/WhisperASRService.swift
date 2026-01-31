//
//  WhisperASRService.swift
//  VibeCaption
//
//  Created by VibeCaption AI.
//

import Foundation
import whisper // Assumes whisper.spm or similar package is added

/// Real implementation of ASRServiceProtocol using Whisper.cpp
public actor WhisperASRService: ASRServiceProtocol {
    
    private let modelManager: ModelManager
    private var context: OpaquePointer?
    private let logger: Logger
    
    public private(set) var isModelLoaded: Bool = false
    
    // Whisper constants
    // Sample rate is typically 16000 for Whisper
    private let sampleRate: Float = 16000.0
    
    public init(modelManager: ModelManager) {
        self.modelManager = modelManager
        self.logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "com.vibecaption",
            category: "WhisperASRService"
        )
    }
    
    deinit {
        unloadModel()
    }
    
    public func loadModel() async throws {
        guard !isModelLoaded else { return }
        
        // 1. Get model path
        guard let modelID = modelManager.getASRModelID(),
              let modelInfo = modelManager.getModel(id: modelID) else {
            throw ModelError.modelNotFound("Preferred Whisper model")
        }
        
        guard let modelPath = modelManager.getModelPath(for: modelInfo)?.path else {
            throw ModelError.invalidInstallation
        }
        
        if !FileManager.default.fileExists(atPath: modelPath) {
            throw ModelError.modelNotFound(modelID)
        }
        
        logger.info("Loading Whisper model from: \(modelPath)")
        
        // 2. Initialize Whisper Context
        // whisper_init_from_file returns OpaquePointer to whisper_context
        guard let ctx = whisper_init_from_file(modelPath) else {
            logger.error("Failed to initialize whisper context")
            throw ASRServiceError.initializationFailed
        }
        
        self.context = ctx
        self.isModelLoaded = true
        logger.info("Whisper model loaded successfully")
    }
    
    public func unloadModel() {
        if let ctx = context {
            whisper_free(ctx)
            context = nil
        }
        isModelLoaded = false
        logger.info("Whisper model unloaded")
    }
    
    public func transcribe(_ audio: AudioSegment) async throws -> ASRResult {
        guard let ctx = context, isModelLoaded else {
            throw ASRServiceError.modelNotLoaded
        }
        
        let startProcessing = Date()
        
        // 1. Convert/Resample audio if necessary
        // Whisper expects 16kHz PCM Float32.
        // Assuming AudioSegment already provides this format but checks might be needed.
        // For V1 we assume AudioSegment is standard.
        var pcmData = audio.audioData
        
        if pcmData.isEmpty {
             return ASRResult(segments: [], processingTime: 0)
        }
        
        // 2. Setup Paremeters
        // whisper_full_default_params(strategy)
        // strategy: WHISPER_SAMPLING_GREEDY (0) or WHISPER_SAMPLING_BEAM_SEARCH (1)
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        
        // Configure params
        params.print_realtime = false
        params.print_progress = false
        params.print_timestamps = false
        params.print_special = false
        params.translate = false
        params.language = "ja".cString(using: .utf8) // Target Japanese as requested
        params.n_threads = Int32(min(4, ProcessInfo.processInfo.processorCount))
        params.offset_ms = 0
        
        // 3. Run Inference
        logger.debug("Starting whisper_full inference on \(pcmData.count) samples")
        
        let ret = pcmData.withUnsafeMutableBufferPointer { buffer in
            whisper_full(ctx, params, buffer.baseAddress, Int32(buffer.count))
        }
        
        if ret != 0 {
            logger.error("whisper_full failed with code \(ret)")
            throw ASRServiceError.transcriptionFailed
        }
        
        // 4. Parse Results
        var segments: [ASRSegment] = []
        let nSegments = whisper_full_n_segments(ctx)
        
        for i in 0..<nSegments {
            guard let textPtr = whisper_full_get_segment_text(ctx, i) else { continue }
            let text = String(cString: textPtr)
            
            let t0 = whisper_full_get_segment_t0(ctx, i)
            let t1 = whisper_full_get_segment_t1(ctx, i)
            
            // Whisper timestamps are in 10ms units (sentinels are negative)
            // startTime is relative to the provided audio chunk
            let segStart = TimeInterval(t0) / 100.0
            let segEnd = TimeInterval(t1) / 100.0
            
            // Adjust to absolute time if AudioSegment has absolute start
            let absoluteStart = audio.startTime + segStart
            let absoluteEnd = audio.startTime + segEnd
            
            let segment = ASRSegment(
                text: text,
                startTime: absoluteStart,
                endTime: absoluteEnd,
                speakerID: nil, // Diarization not supported in base whisper
                confidence: 1.0 // TODO: Extract per-token probs if needed
            )
            segments.append(segment)
        }
        
        let processingTime = Date().timeIntervalSince(startProcessing)
        logger.info("Transcribed \(segments.count) segments in \(processingTime)s")
        
        return ASRResult(segments: segments, processingTime: processingTime)
    }
}

// MARK: - Import Helpers
// Necessary if OpaquePointer/C-types need specific bridging
// but standard bridging usually works.

// Add Logger shim if not globally available (implied it exists in project from ModelManager usage)
import os.log
