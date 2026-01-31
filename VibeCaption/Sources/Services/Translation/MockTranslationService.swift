import Foundation

public enum MockTranslationError: Error {
    case modelNotLoaded
    case translationFailed
    case simulatedFailure
}

public class MockTranslationService: TranslationServiceProtocol {
    
    public struct Configuration {
        public enum Mode {
            case highConfidence
            case lowConfidence
            case failure
        }
        
        public var mode: Mode
        public var delayRange: Range<TimeInterval>
        
        public static let `default` = Configuration(mode: .highConfidence, delayRange: 0.3..<1.0)
    }
    
    public var config: Configuration
    private(set) public var isModelLoaded: Bool = false
    
    private let commonPhrases: [String: String] = [
        "こんにちは": "Hello",
        "おはようございます": "Good morning",
        "こんばんは": "Good evening",
        "ありがとう": "Thank you",
        "さようなら": "Goodbye",
        "はい": "Yes",
        "いいえ": "No",
        "元気ですか": "How are you?",
        "はじめまして": "Nice to meet you",
        "私の名前は...です": "My name is..."
    ]
    
    public init(config: Configuration = .default) {
        self.config = config
    }
    
    public func loadModel() async throws {
        // Simulate loading time
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        isModelLoaded = true
    }
    
    public func unloadModel() {
        isModelLoaded = false
    }
    
    public func translate(_ text: String, from sourceLanguage: Language, to targetLanguage: Language) async throws -> TranslationResult {
        guard isModelLoaded else {
            throw MockTranslationError.modelNotLoaded
        }
        
        // Simulate delay based on text length but clamped within config range
        let baseDelay = Double(text.count) * 0.05
        let delay = min(max(baseDelay, config.delayRange.lowerBound), config.delayRange.upperBound)
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        if config.mode == .failure {
            throw MockTranslationError.simulatedFailure
        }
        
        let translatedText: String
        let confidence: Double
        
        if sourceLanguage == .japanese && targetLanguage == .english {
            translatedText = commonPhrases[text] ?? "[MOCK] \(text)"
        } else {
             translatedText = "[MOCK] \(text)"
        }
        
        switch config.mode {
        case .highConfidence:
            confidence = Double.random(in: 0.85...0.99)
        case .lowConfidence:
            confidence = Double.random(in: 0.3...0.6)
        case .failure:
            fatalError("Should have thrown error earlier")
        }
        
        return TranslationResult(
            originalText: text,
            translatedText: translatedText,
            confidence: confidence,
            processingTime: delay,
            targetLanguage: targetLanguage
        )
    }
}
