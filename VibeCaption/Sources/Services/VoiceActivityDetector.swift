import Foundation
import AVFoundation
import Combine

/// Result of Voice Activity Detection
enum VADResult: Equatable {
    case speech
    case silence
    case uncertain
    
    // Confidence score 0.0 to 1.0
    var confidence: Float {
        switch self {
        case .speech: return 1.0
        case .silence: return 1.0
        case .uncertain: return 0.5
        }
    }
}

/// Detects voice activity in audio buffers based on energy threshold.
class VoiceActivityDetector: ObservableObject {
    // MARK: - Properties
    
    @Published var isSpeechDetected: Bool = false
    
    // Configuration
    // Tuned for typical meeting/system-audio levels where RMS often sits below 0.05.
    // Higher defaults can prevent segment start and make transcription appear "stuck".
    var speechThreshold: Float = 0.008 // ~ -42 dBFS
    var silenceThreshold: Float = 0.0025 // ~ -52 dBFS
    
    // State
    private var consecutiveSpeechFrames = 0
    private var consecutiveSilenceFrames = 0
    
    // Hysteresis configuration
    private let requiredSpeechFrames = 2 // Faster activation for live calls
    private let requiredSilenceFrames = 5
    
    // MARK: - Initialization
    
    init(speechThreshold: Float = 0.008, silenceThreshold: Float = 0.0025) {
        self.speechThreshold = speechThreshold
        self.silenceThreshold = silenceThreshold
    }
    
    // MARK: - Public Methods
    
    /// Process an audio buffer and determine if it contains speech
    func process(_ buffer: AVAudioPCMBuffer) -> VADResult {
        guard let channelData = buffer.floatChannelData else {
            return .uncertain
        }
        
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else {
            return isSpeechDetected ? .speech : .silence
        }
        var sumSquares: Float = 0
        
        // Calculate RMS (Energy) of the buffer
        // Using the first channel for simplicity, or average of all?
        // Let's use average energy across all channels or just mono downmix concept
        // For efficiency, just checking first channel is often enough for VAD if microphone is mono/stereo
        
        let dataPointer = channelData[0] // Assume channel 0
        
        // vDSP could be faster, but simple loop is fine for small buffers
        for i in 0..<frameLength {
            let sample = dataPointer[i]
            sumSquares += sample * sample
        }
        
        let rms = sqrt(sumSquares / Float(frameLength))
        
        // State Machine with Hysteresis
        if rms > speechThreshold {
            consecutiveSpeechFrames += 1
            consecutiveSilenceFrames = 0
        } else if rms < silenceThreshold {
            consecutiveSilenceFrames += 1
            consecutiveSpeechFrames = 0
        } else {
            // In the "uncertain" zone between thresholds
            // Keep previous state logic effectively, or just don't reset counters?
            // Simple approach: treat uncertain as "not changing state strongly"
            // But usually we treat it as "maintaining status quo"
        }
        
        // Determine result based on counters
        let result: VADResult
        
        if consecutiveSpeechFrames >= requiredSpeechFrames {
            isSpeechDetected = true
            result = .speech
        } else if consecutiveSilenceFrames >= requiredSilenceFrames {
            isSpeechDetected = false
            result = .silence
        } else {
            // Keep current state if in transition
            result = isSpeechDetected ? .speech : .silence
        }
        
        return result
    }
    
    /// Reset internal state
    func reset() {
        consecutiveSpeechFrames = 0
        consecutiveSilenceFrames = 0
        isSpeechDetected = false
    }
}
