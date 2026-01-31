import Foundation

/// Represents a continuous segment of speech audio ready for processing
struct AudioSegment {
    /// Start time of the segment relative to session start (or absolute, depending on usage)
    let startTime: TimeInterval
    
    /// End time of the segment
    let endTime: TimeInterval
    
    /// Raw audio samples (PCM Float32)
    /// Usually converted to the target format (e.g., 16kHz Mono)
    let audioData: [Float]
    
    /// Rough estimate of word count (e.g. based on duration/density)
    /// Useful for UI placeholders or progress bars
    var estimatedWordCount: Int {
        let duration = endTime - startTime
        // Rough avg: 150 words per minute ~ 2.5 words per second
        return max(1, Int(duration * 2.5))
    }
    
    /// Duration of the segment
    var duration: TimeInterval {
        return endTime - startTime
    }
}
