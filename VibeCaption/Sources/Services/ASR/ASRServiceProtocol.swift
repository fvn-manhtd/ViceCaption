import Foundation

/// Protocol for ASR services.
/// Implementations can be real (Whisper) or mock (for tests/dev).
protocol ASRServiceProtocol: AnyObject {
    /// Load underlying model/resources
    func loadModel() async throws
    
    /// Unload/free resources
    func unloadModel()
    
    /// Whether the model is currently loaded
    var isModelLoaded: Bool { get }
    
    /// Transcribe a single audio segment
    func transcribe(_ audio: AudioSegment) async throws -> ASRResult
}

