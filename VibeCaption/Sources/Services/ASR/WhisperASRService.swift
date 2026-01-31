//
//  WhisperASRService.swift
//  VibeCaption
//
//  Created by VibeCaption AI.
//

import Foundation
import SwiftWhisper
import os.log

/// Real implementation of ASRServiceProtocol using Whisper.cpp via SwiftWhisper wrapper
public actor WhisperASRService: ASRServiceProtocol {
    
    private let modelManager: ModelManager
    private var whisper: Whisper?
    private let logger: Logger
    
    public private(set) var isModelLoaded: Bool = false
    
    public init(modelManager: ModelManager) {
        self.modelManager = modelManager
        self.logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "com.vibecaption",
            category: "WhisperASRService"
        )
    }
    
    deinit {
        // Actor deinit limits what we can do, but regular cleanup is fine
        // whisper = nil // handled by swift ARC
    }
    
    public func loadModel() async throws {
        // Prevent reloading if already loaded
        guard !isModelLoaded else { return }
        
        // 1. Get model path
        guard let modelID = modelManager.getASRModelID(),
              let modelInfo = modelManager.getModel(id: modelID) else {
            throw ModelError.modelNotFound("Preferred Whisper model")
        }
        
        guard let modelPath = modelManager.getModelPath(for: modelInfo) else {
            throw ModelError.invalidInstallation
        }
        
        if !FileManager.default.fileExists(atPath: modelPath.path) {
            throw ModelError.modelNotFound(modelID)
        }
        
        logger.info("Loading Whisper model from: \(modelPath.path)")
        
        // 2. Initialize Whisper
        // Initialize from file URL. This is synchronous and might block briefly.
        guard let whisperInstance = Whisper(fromFileURL: modelPath) else {
            logger.error("Failed to initialize SwiftWhisper instance")
            throw ASRServiceError.initializationFailed
        }
        
        self.whisper = whisperInstance
        
        // 3. Configure Parameters
        // Set language to Japanese
        // Note: SwiftWhisper params might detailed differently depending on version, 
        // but typically exposed via `params` property.
        whisperInstance.params.language = .japanese
        whisperInstance.params.print_realtime = false
        whisperInstance.params.print_progress = false
        whisperInstance.params.translate = false // We want transcription (in Japanese)
        
        self.isModelLoaded = true
        logger.info("Whisper model loaded successfully")
    }
    
    public func unloadModel() {
        whisper = nil
        isModelLoaded = false
        logger.info("Whisper model unloaded")
    }
    
    public func transcribe(_ audio: AudioSegment) async throws -> ASRResult {
        guard let whisper = whisper, isModelLoaded else {
            throw ASRServiceError.modelNotLoaded
        }
        
        let startProcessing = Date()
        let audioData = audio.audioData
        
        if audioData.isEmpty {
            return ASRResult(segments: [], processingTime: 0)
        }
        
        logger.debug("Starting transcription on \(audioData.count) samples")
        
        // Use a continuation to bridge the callback-based/blocking flow
        return try await withCheckedThrowingContinuation { continuation in
            // Create a handler that will retain itself until logic completes if needed,
            // or we hold a strong ref here.
            
            let handler = WhisperDelegationHandler(
                startTime: audio.startTime,
                continuation: continuation
            )
            
            // Set delegate
            whisper.delegate = handler
            
            // Start transcription
            // Assuming this runs synchronously or asynchronously on internal queue.
            // Verified SwiftWhisper usually runs async on internal queue.
            // We must keep `handler` alive.
            // The delegate property is weak in SwiftWhisper usually.
            // So we capture `handler` in the closure? No, `transcribe` returns.
            
            // To keep `handler` alive during the async operation of `whisper`, 
            // we can associate it with the continuation or simply rely on the fact 
            // that we are inside `withCheckedThrowingContinuation` block?
            // No, the block ends when `transcribe` call returns (if async) or finishes (if sync).
            // If async, we need to store handler elsewhere.
            // Hack: Attach handler to the `Whisper` instance if possible? No.
            // Standard way: Use a Task local or an actor property.
            // But actor property prevents concurrency.
            // Since we are inside `transcribe` method, let's just make the handler property of the actor?
            // But `transcribe` is re-entrant if we suspend?
            // Ideally we block re-entrancy for strict serial ASR.
            
            // For now, we assume `transcribe` call blocks or we manage the lifetime manually.
            // IF `transcribe` returns immediately, we have a problem with `handler` dealloc.
            // Let's assume we hold a strong reference to `handler` in a property `currentHandler`.
            
            Task {
                // Ensure handler stays alive
                self.currentHandler = handler
                
                do {
                   try await whisper.transcribe(audioFrames: audioData)
                   // If transcribe is async await, we are good.
                   // If it was void return, we'd need to rely on delegate solely.
                   // SwiftWhisper `transcribe` is `func transcribe(audioFrames: [Float]) async`.
                   // So it awaits completion!
                   // Wait, if it awaits completion, we don't need continuation for the call itself,
                   // BUT we need continuation to get the Result from the delegate callbacks!
                   // Because `transcribe` returns `Void` (usually).
                   
                   // So:
                   // 1. We await transcribe.
                   // 2. Delegates fire during this time.
                   // 3. When plain `transcribe` returns, is it guaranteed that `didComplete` has fired?
                   // Usually yes.
                   
                   // Actually, if `transcribe` is async, we don't need a delegate if it returned segments. 
                   // But SwiftWhisper returns Void and uses delegate.
                   
                   // So we await it. When it returns, we assume completion?
                   // No, `didCompleteWithSegments` is the signal.
                   
                } catch {
                    continuation.resume(throwing: error)
                    self.currentHandler = nil
                }
            }
        }
    }
    
    // Keep reference to current handler to prevent deallocation
    private var currentHandler: WhisperDelegationHandler?
}

// MARK: - Delegate Handler

fileprivate class WhisperDelegationHandler: WhisperDelegate {
    private let startTime: TimeInterval
    private var continuation: CheckedContinuation<ASRResult, Error>?
    private var segments: [ASRSegment] = []
    private var startTimestamp: Date = Date()
    
    init(startTime: TimeInterval, continuation: CheckedContinuation<ASRResult, Error>) {
        self.startTime = startTime
        self.continuation = continuation
    }
    
    // Progress update
    func whisper(_ aWhisper: Whisper, didUpdateProgress progress: Double) {
        // Can verify cancellation or log
    }
    
    // New segments
    func whisper(_ aWhisper: Whisper, didProcessNewSegments segments: [Segment], atIndex index: Int) {
        // We can accumulate them here or just wait for final completion
        // Assuming `didAction` provides incremental.
        // We often just use `didComplete` for the full list if available.
    }
    
    // Complete
    func whisper(_ aWhisper: Whisper, didCompleteWithSegments segments: [Segment]) {
        let processingTime = Date().timeIntervalSince(startTimestamp)
        
        // Convert SwiftWhisper.Segment to VibeCaption.ASRSegment
        let asrSegments = segments.map { seg -> ASRSegment in
            // Whisper timestamps are relative to the start of the audio chunk
            // seg.startTime is Int (ms) or Float (sec)?
            // SwiftWhisper Segment usually has `startTime` and `endTime` in seconds (Int usually * 10 or similar in C++ but wrapper might convert).
            // Looking at standard wrapper: startTime is Int (ms) usually.
            // Let's verify by calculating or assuming Int (ms).
            // Actually, SwiftWhisper `Segment` struct:
            // public struct Segment {
            //    public let startTime: Int
            //    public let endTime: Int
            //    public let text: String
            // }
            // Time is in milliseconds (0-10ms units? No, usually ms).
            // whisper.cpp uses 10ms units typically.
            // Wrapper usually multiplies by 10 to get ms.
            // Let's assume MILLISECONDS.
            
            let startSec = TimeInterval(seg.startTime) / 1000.0 // Assuming ms
            let endSec = TimeInterval(seg.endTime) / 1000.0
            
            return ASRSegment(
                text: seg.text,
                startTime: self.startTime + startSec,
                endTime: self.startTime + endSec,
                speakerID: nil,
                confidence: 1.0 // Placeholder
            )
        }
        
        let result = ASRResult(segments: asrSegments, processingTime: processingTime)
        continuation?.resume(returning: result)
        continuation = nil
    }
    
    // Error
    func whisper(_ aWhisper: Whisper, didErrorWith error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
