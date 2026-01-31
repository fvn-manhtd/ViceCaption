import Foundation

public protocol TranslationServiceProtocol: AnyObject {
    /// Indicates whether the translation model is currently loaded in memory
    var isModelLoaded: Bool { get }
    
    /// Loads the translation model resources
    func loadModel() async throws
    
    /// Unloads the translation model to free up resources
    func unloadModel()
    
    /// Translates text from one language to another
    /// - Parameters:
    ///   - text: The text to translate
    ///   - sourceLanguage: The source language of the text
    ///   - targetLanguage: The target language for the translation
    /// - Returns: A TranslationResult containing the translated text and metadata
    func translate(_ text: String, from sourceLanguage: Language, to targetLanguage: Language) async throws -> TranslationResult
}
