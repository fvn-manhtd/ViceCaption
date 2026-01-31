import Foundation

/// Full result of transcribing an audio chunk
struct ASRResult: Equatable, Codable {
    /// Ordered list of recognized segments
    let segments: [ASRSegment]
    
    /// Total processing time the engine took for this transcription
    let processingTime: TimeInterval
}

