import Foundation

/// Factory for creating ASR services (mock vs real)
enum ASRServiceFactory {
    static func getService(modelManager: ModelManager, useMock: Bool) -> ASRServiceProtocol {
        #if DEBUG
        if useMock { return MockASRService() }
        #endif
        if useMock { return MockASRService() }
        return WhisperASRService(modelManager: modelManager)
    }
}

