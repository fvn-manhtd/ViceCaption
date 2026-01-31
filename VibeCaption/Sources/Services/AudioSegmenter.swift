import Foundation
import AVFoundation

/// Breaks continuous audio into discrete speech segments
class AudioSegmenter {
    // MARK: - Properties
    
    // Configuration
    var minSegmentDuration: TimeInterval = 0.5
    var maxSegmentDuration: TimeInterval = 10.0
    var silencePadding: TimeInterval = 0.3 // Keep some silence after speech chunks
    
    // Callback
    private var segmentCallback: ((AudioSegment) -> Void)?
    
    // Internal buffering
    private var buffer: [Float] = []
    private var segmentStartTime: TimeInterval?
    
    // Timing tracking (naive increment based on buffer size)
    private var currentTime: TimeInterval = 0
    private var sampleRate: Double = 16000.0 // Default assumption, should update on first buffer
    
    // State
    private var isRecordingSegment = false
    private var silenceDurationInsideSegment: TimeInterval = 0
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Public API
    
    func setSegmentCallback(_ callback: @escaping (AudioSegment) -> Void) {
        self.segmentCallback = callback
    }
    
    func process(_ buffer: AVAudioPCMBuffer, vadResult: VADResult) {
        // Update sample rate reference if needed
        if sampleRate != buffer.format.sampleRate {
            sampleRate = buffer.format.sampleRate
        }
        
        // Extract float data
        guard let channelData = buffer.floatChannelData else { return }
        let channelPtr = channelData[0]
        let frameCount = Int(buffer.frameLength)
        let bufferDuration = Double(frameCount) / sampleRate
        
        // Append data to buffer if we are inside a potential segment or starting one
        // Ideally we should have a circular buffer to capture *Lookbehind* (pre-speech padding)
        // For now, implementing simple start-on-speech
        
        // Logic:
        // 1. If VAD == speech: Start segment if not started. Reset silence counter.
        // 2. If VAD == silence: Increment silence counter.
        // 3. If silence > padding && segment duration > min: Finalize segment.
        // 4. If segment duration > max: Force finalize.
        
        if vadResult == .speech {
            if !isRecordingSegment {
                startSegment()
            }
            silenceDurationInsideSegment = 0
        } else if isRecordingSegment {
            silenceDurationInsideSegment += bufferDuration
        }
        
        if isRecordingSegment {
            // Append audio data
            // Swift array append is reasonably efficient for floats, but Memcpy is faster
            // For MVP, loop conformant
            // Optimization: UnsafeBufferPointer
            let bufferPtr = UnsafeBufferPointer(start: channelPtr, count: frameCount)
            self.buffer.append(contentsOf: bufferPtr)
            
            // Checks for termination
            let currentSegmentDuration = Double(self.buffer.count) / sampleRate
            
            let isMaxDurationReached = currentSegmentDuration >= maxSegmentDuration
            let isSilenceTimeout = silenceDurationInsideSegment >= silencePadding
            
            if isMaxDurationReached || (isSilenceTimeout && currentSegmentDuration >= minSegmentDuration) {
                finalizeSegment()
            }
        }
        
        // Advance internal time tracker
        currentTime += bufferDuration
    }
    
    func reset() {
        buffer.removeAll()
        isRecordingSegment = false
        silenceDurationInsideSegment = 0
        segmentStartTime = nil
        currentTime = 0
    }
    
    // MARK: - Private Helpers
    
    private func startSegment() {
        isRecordingSegment = true
        segmentStartTime = currentTime
        // Note: Real world implementation would pull from a ring buffer here
        // to add pre-speech context (e.g. 0.2s before trigger)
    }
    
    private func finalizeSegment() {
        guard let start = segmentStartTime, !buffer.isEmpty else {
            resetStatePartial()
            return
        }
        
        // Check constraints one last time (e.g. min duration)
        let duration = Double(buffer.count) / sampleRate
        if duration >= minSegmentDuration {
            let segment = AudioSegment(
                startTime: start,
                endTime: start + duration,
                audioData: buffer,
                estimatedWordCount: 0 // Will be calc'd by struct
            )
            segmentCallback?(segment)
        }
        
        resetStatePartial()
    }
    
    private func resetStatePartial() {
        buffer.removeAll(keepingCapacity: true)
        isRecordingSegment = false
        silenceDurationInsideSegment = 0
        segmentStartTime = nil
    }
}
