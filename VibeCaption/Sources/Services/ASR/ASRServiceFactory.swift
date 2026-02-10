import Foundation

/// Factory for creating ASR services (mock vs real, engine selection)
enum ASRServiceFactory {
    static func getService(
        modelManager: ModelManager? = nil,
        useMock: Bool = false,
        engine: ASREngineType = .appleSpeech
    ) -> ASRServiceProtocol {
        #if DEBUG
        if useMock { return MockASRService() }
        #endif
        if useMock { return MockASRService() }

        switch engine {
        case .appleSpeech:
            return SpeechASRService()
        case .whisper:
            guard let modelManager else {
                // Fallback to Apple Speech if no ModelManager provided
                return SpeechASRService()
            }
            return WhisperASRService(modelManager: modelManager)
        }
    }
}

