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
    private let asrService: ASRServiceProtocol
    private let translationService: TranslationServiceProtocol
    
    private let logger = Logger(subsystem: "com.vibecaption", category: "CaptionPipeline")
    
    // MARK: - State
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(captureEngine: AudioCaptureEngine = AudioCaptureEngine()) {
        self.captureEngine = captureEngine
        self.vad = VoiceActivityDetector()
        self.segmenter = AudioSegmenter()
        self.asrService = ASRServiceFactory.getService(useMock: true)
        self.translationService = TranslationServiceFactory.shared.getService(useMock: true) // Using Mock for now as per requirements
        
        setupPipeline()
        
        // Ensure translation model is loaded
        Task {
            try? await self.translationService.loadModel()
        }
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

        // Process ASR for the completed segment
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let result = try await self.asrService.transcribe(segment)
                var blocks = self.convertToTranscriptBlocks(result)
                
                // Log ASR results
                let japaneseLog = blocks.map { $0.japaneseText }.joined(separator: " | ")
                self.logger.info("ASR Result: \(japaneseLog)")
                
                // Translate blocks
                for i in 0..<blocks.count {
                    do {
                        let translation = try await self.translationService.translate(
                            blocks[i].japaneseText,
                            from: .japanese,
                            to: .english
                        )
                        blocks[i].englishText = translation.translatedText
                        self.logger.info("Translation Result: \(translation.translatedText) (Confidence: \(translation.confidence))")
                    } catch {
                        self.logger.error("Translation failed for block \(i): \(error.localizedDescription)")
                    }
                }
                
                // TODO: Emit blocks to TranscriptManager
                
            } catch {
                self.logger.error("ASR failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Conversion
    private func convertToTranscriptBlocks(_ asr: ASRResult) -> [TranscriptBlock] {
        asr.segments.map { seg in
            TranscriptBlock(
                speakerLabel: seg.speakerID.map { "Speaker \($0)" },
                japaneseText: seg.text,
                confidence: seg.confidence
            )
        }
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
