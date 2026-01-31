import Foundation

/// Factory for creating ASR services (mock vs real)
enum ASRServiceFactory {
    static func getService(useMock: Bool) -> ASRServiceProtocol {
        #if DEBUG
        if useMock { return MockASRService() }
        #endif
        if useMock { return MockASRService() }
        return WhisperASRServiceStub()
    }
}

/// Temporary stub for the real ASR (to be replaced by Whisper integration)
final class WhisperASRServiceStub: ASRServiceProtocol {
    private(set) var isModelLoaded: Bool = false
    
    func loadModel() async throws {
        isModelLoaded = true
    }
    
    func unloadModel() {
        isModelLoaded = false
    }
    
    func transcribe(_ audio: AudioSegment) async throws -> ASRResult {
        // Return empty for now; real implementation will integrate Whisper
        return ASRResult(segments: [], processingTime: 0)
    }
}

