import Foundation
import AVFoundation
import Combine
import os.log

/// Orchestrates the audio capture, VAD, segmentation, and ASR pipeline.
class CaptionPipeline: ObservableObject {
    
    // MARK: - Dependencies
    
    private let captureEngine: AudioCaptureEngine
    private let vad: VoiceActivityDetector
    private let segmenter: AudioSegmenter
    
    private let logger = Logger(subsystem: "com.vibecaption", category: "CaptionPipeline")
    
    // MARK: - State
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(captureEngine: AudioCaptureEngine = AudioCaptureEngine()) {
        self.captureEngine = captureEngine
        self.vad = VoiceActivityDetector()
        self.segmenter = AudioSegmenter()
        
        setupPipeline()
    }
    
    // MARK: - Setup
    
    private func setupPipeline() {
        // Wire AudioCapture -> VAD -> Segmenter
        captureEngine.setAudioCallback { [weak self] buffer in
            self?.processAudio(buffer)
        }
        
        // Handle Segment output
        segmenter.setSegmentCallback { [weak self] segment in
            self?.handleSegment(segment)
        }
        
        // Bind VAD state to UI/Logic if needed
        vad.$isSpeechDetected
            .sink { [weak self] isSpeech in
                // self?.logger.debug("Speech detected: \(isSpeech)")
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Processing
    
    private func processAudio(_ buffer: AVAudioPCMBuffer) {
        // 1. Run VAD
        let vadResult = vad.process(buffer)
        
        // 2. Pass to Segmenter
        segmenter.process(buffer, vadResult: vadResult)
    }
    
    private func handleSegment(_ segment: AudioSegment) {
        logger.info("Generated Audio Segment: \(segment.duration)s, \(segment.estimatedWordCount) est. words")
        
        // 3. Queue for ASR (Stub)
        // ASRQueue.shared.enqueue(segment)
        // print("Sent to ASR queue")
    }
    
    // MARK: - Control
    
    func start() throws {
        try captureEngine.startCapture()
    }
    
    func stop() {
        captureEngine.stopCapture()
        vad.reset()
        segmenter.reset()
    }
}
