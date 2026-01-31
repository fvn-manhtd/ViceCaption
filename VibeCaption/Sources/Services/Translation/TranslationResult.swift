import Foundation

public struct TranslationResult: Codable, Equatable {
    public let originalText: String
    public let translatedText: String
    public let confidence: Double
    public let processingTime: TimeInterval
    public let targetLanguage: Language
    
    public init(
        originalText: String,
        translatedText: String,
        confidence: Double,
        processingTime: TimeInterval,
        targetLanguage: Language
    ) {
        self.originalText = originalText
        self.translatedText = translatedText
        self.confidence = confidence
        self.processingTime = processingTime
        self.targetLanguage = targetLanguage
    }
}
