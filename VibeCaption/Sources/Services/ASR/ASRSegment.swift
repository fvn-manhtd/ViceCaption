import Foundation

/// One recognized text segment within an ASR result
struct ASRSegment: Equatable, Codable {
    /// Recognized Japanese text
    let text: String
    
    /// Segment start time (seconds, relative to the audio input)
    let startTime: TimeInterval
    
    /// Segment end time (seconds, relative to the audio input)
    let endTime: TimeInterval
    
    /// Optional speaker identifier (1-3 for mock)
    let speakerID: Int?
    
    /// Confidence score (0.0 - 1.0)
    let confidence: Double
}

