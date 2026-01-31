//
//  NLLBTokenizer.swift
//  VibeCaption
//
//  Handles SentencePiece tokenization for NLLB-200 translation model.
//

import Foundation
import os.log

// MARK: - Tokenizer Error

public enum NLLBTokenizerError: Error, LocalizedError {
    case vocabularyNotFound(path: String)
    case vocabularyLoadFailed(Error)
    case invalidVocabularyFormat
    case encodingFailed(reason: String)
    case decodingFailed(reason: String)
    case unsupportedLanguage(Language)
    
    public var errorDescription: String? {
        switch self {
        case .vocabularyNotFound(let path):
            return "Vocabulary file not found at: \(path)"
        case .vocabularyLoadFailed(let error):
            return "Failed to load vocabulary: \(error.localizedDescription)"
        case .invalidVocabularyFormat:
            return "Invalid vocabulary file format"
        case .encodingFailed(let reason):
            return "Text encoding failed: \(reason)"
        case .decodingFailed(let reason):
            return "Token decoding failed: \(reason)"
        case .unsupportedLanguage(let language):
            return "Unsupported language: \(language.displayName)"
        }
    }
}

// MARK: - NLLB Language Codes

/// NLLB-200 uses FLORES-200 language codes (BCP-47 based)
public struct NLLBLanguageCodes {
    /// Japanese language code for NLLB-200
    public static let japanese = "jpn_Jpan"
    
    /// English language code for NLLB-200
    public static let english = "eng_Latn"
    
    /// Convert VibeCaption Language enum to NLLB code
    public static func code(for language: Language) -> String? {
        switch language {
        case .japanese:
            return japanese
        case .english:
            return english
        }
    }
}

// MARK: - Special Tokens

/// Special tokens used by NLLB-200 model
public struct NLLBSpecialTokens {
    /// Beginning of sequence token
    public static let bos = "<s>"
    public static let bosID: Int32 = 0
    
    /// Padding token
    public static let pad = "<pad>"
    public static let padID: Int32 = 1
    
    /// End of sequence token
    public static let eos = "</s>"
    public static let eosID: Int32 = 2
    
    /// Unknown token
    public static let unk = "<unk>"
    public static let unkID: Int32 = 3
}

// MARK: - NLLB Tokenizer

/// Tokenizer for NLLB-200 translation model
///
/// Handles encoding text to token IDs and decoding token IDs back to text.
/// Uses SentencePiece vocabulary for subword tokenization.
///
/// Example:
/// ```swift
/// let tokenizer = NLLBTokenizer()
/// try tokenizer.loadVocabulary(from: vocabURL)
///
/// let tokens = try tokenizer.encode("こんにちは", sourceLanguage: .japanese, targetLanguage: .english)
/// let text = try tokenizer.decode(outputTokens)
/// ```
public final class NLLBTokenizer {
    
    // MARK: - Properties
    
    /// Token to ID mapping
    private var tokenToID: [String: Int32] = [:]
    
    /// ID to token mapping
    private var idToToken: [Int32: String] = [:]
    
    /// Language code token IDs (cached for performance)
    private var languageCodeIDs: [String: Int32] = [:]
    
    /// Maximum sequence length supported
    public var maxSequenceLength: Int = 256
    
    /// Whether vocabulary is loaded
    public private(set) var isLoaded: Bool = false
    
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.vibecaption",
        category: "NLLBTokenizer"
    )
    
    // MARK: - Unicode normalization for Japanese
    
    /// SentencePiece uses NFKC normalization
    private func normalizeText(_ text: String) -> String {
        // NFKC normalization as used by SentencePiece
        return text.precomposedStringWithCompatibilityMapping
    }
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Vocabulary Loading
    
    /// Load vocabulary from a file
    ///
    /// Supports multiple formats:
    /// - JSON format: `{"token": id, ...}` or `[{"token": "...", "id": ...}, ...]`
    /// - Text format: one token per line, ID is line number
    ///
    /// - Parameter url: URL to the vocabulary file
    /// - Throws: `NLLBTokenizerError` if loading fails
    public func loadVocabulary(from url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw NLLBTokenizerError.vocabularyNotFound(path: url.path)
        }
        
        do {
            let data = try Data(contentsOf: url)
            
            // Try JSON format first
            if let jsonDict = try? JSONSerialization.jsonObject(with: data) as? [String: Int] {
                // Format: {"token": id, ...}
                for (token, id) in jsonDict {
                    let id32 = Int32(id)
                    tokenToID[token] = id32
                    idToToken[id32] = token
                }
            } else if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                // Format: [{"token": "...", "id": ...}, ...]
                for item in jsonArray {
                    guard let token = item["token"] as? String,
                          let id = item["id"] as? Int else {
                        continue
                    }
                    let id32 = Int32(id)
                    tokenToID[token] = id32
                    idToToken[id32] = token
                }
            } else {
                // Try text format: one token per line
                guard let content = String(data: data, encoding: .utf8) else {
                    throw NLLBTokenizerError.invalidVocabularyFormat
                }
                
                let lines = content.components(separatedBy: .newlines)
                for (index, line) in lines.enumerated() {
                    let token = line.trimmingCharacters(in: .whitespaces)
                    if !token.isEmpty {
                        let id = Int32(index)
                        tokenToID[token] = id
                        idToToken[id] = token
                    }
                }
            }
            
            // Validate we have minimum required tokens
            guard tokenToID.count > 100 else {
                throw NLLBTokenizerError.invalidVocabularyFormat
            }
            
            // Cache language code IDs
            cacheLanguageCodeIDs()
            
            isLoaded = true
            logger.info("Loaded vocabulary with \(self.tokenToID.count) tokens")
            
        } catch let error as NLLBTokenizerError {
            throw error
        } catch {
            throw NLLBTokenizerError.vocabularyLoadFailed(error)
        }
    }
    
    /// Load vocabulary from a SentencePiece model file (.model)
    ///
    /// Note: This is a simplified implementation that reads the vocabulary
    /// portion. For full SentencePiece support, use the swift-sentencepiece package.
    ///
    /// - Parameter url: URL to the .model file
    /// - Throws: `NLLBTokenizerError` if loading fails
    public func loadSentencePieceModel(from url: URL) throws {
        // For a full implementation, we would use the swift-sentencepiece package
        // This simplified version expects a companion .vocab file
        let vocabURL = url.deletingPathExtension().appendingPathExtension("vocab")
        
        if FileManager.default.fileExists(atPath: vocabURL.path) {
            try loadVocabulary(from: vocabURL)
        } else {
            // Try loading directly if it's already a vocab file
            try loadVocabulary(from: url)
        }
    }
    
    private func cacheLanguageCodeIDs() {
        // Cache common language codes for faster lookup
        for langCode in [NLLBLanguageCodes.japanese, NLLBLanguageCodes.english] {
            if let id = tokenToID[langCode] {
                languageCodeIDs[langCode] = id
            }
        }
    }
    
    // MARK: - Encoding
    
    /// Encode text to token IDs for translation
    ///
    /// The encoded sequence follows NLLB format:
    /// `[source_lang_code] [tokens...] [eos]`
    ///
    /// - Parameters:
    ///   - text: The text to encode
    ///   - sourceLanguage: Source language of the text
    ///   - targetLanguage: Target language for translation (used for decoder)
    /// - Returns: Array of token IDs
    /// - Throws: `NLLBTokenizerError` if encoding fails
    public func encode(_ text: String, sourceLanguage: Language, targetLanguage: Language) throws -> [Int32] {
        guard isLoaded else {
            throw NLLBTokenizerError.encodingFailed(reason: "Vocabulary not loaded")
        }
        
        guard let sourceLangCode = NLLBLanguageCodes.code(for: sourceLanguage) else {
            throw NLLBTokenizerError.unsupportedLanguage(sourceLanguage)
        }
        
        guard let sourceLangID = languageCodeIDs[sourceLangCode] ?? tokenToID[sourceLangCode] else {
            throw NLLBTokenizerError.encodingFailed(reason: "Source language code not in vocabulary")
        }
        
        // Normalize text
        let normalizedText = normalizeText(text)
        
        // Tokenize using simple subword approach
        // Note: Real SentencePiece uses BPE/Unigram. This is a fallback implementation.
        var tokens: [Int32] = []
        
        // Add source language code
        tokens.append(sourceLangID)
        
        // Tokenize the text
        let textTokens = tokenizeText(normalizedText)
        tokens.append(contentsOf: textTokens)
        
        // Add EOS token
        tokens.append(NLLBSpecialTokens.eosID)
        
        // Truncate if needed
        if tokens.count > maxSequenceLength {
            tokens = Array(tokens.prefix(maxSequenceLength - 1)) + [NLLBSpecialTokens.eosID]
        }
        
        return tokens
    }
    
    /// Create decoder initial input with target language code
    ///
    /// - Parameter targetLanguage: Target language for translation
    /// - Returns: Initial token IDs for decoder
    /// - Throws: `NLLBTokenizerError` if the language is not supported
    public func createDecoderInput(targetLanguage: Language) throws -> [Int32] {
        guard let targetLangCode = NLLBLanguageCodes.code(for: targetLanguage) else {
            throw NLLBTokenizerError.unsupportedLanguage(targetLanguage)
        }
        
        guard let targetLangID = languageCodeIDs[targetLangCode] ?? tokenToID[targetLangCode] else {
            throw NLLBTokenizerError.encodingFailed(reason: "Target language code not in vocabulary")
        }
        
        // Decoder input starts with EOS (as BOS) followed by target language code
        return [NLLBSpecialTokens.eosID, targetLangID]
    }
    
    /// Simple tokenization for text
    private func tokenizeText(_ text: String) -> [Int32] {
        var tokens: [Int32] = []
        var remaining = text
        
        // Greedy longest-match tokenization
        while !remaining.isEmpty {
            var found = false
            
            // Try to find the longest matching token
            for length in stride(from: min(remaining.count, 20), through: 1, by: -1) {
                let endIndex = remaining.index(remaining.startIndex, offsetBy: length)
                let candidate = String(remaining[remaining.startIndex..<endIndex])
                
                // Try with SentencePiece prefix (▁ for word start)
                let prefixedCandidate = "▁" + candidate
                
                if let tokenID = tokenToID[prefixedCandidate] {
                    tokens.append(tokenID)
                    remaining = String(remaining[endIndex...])
                    found = true
                    break
                } else if let tokenID = tokenToID[candidate] {
                    tokens.append(tokenID)
                    remaining = String(remaining[endIndex...])
                    found = true
                    break
                }
            }
            
            // If no match found, use character-level fallback
            if !found {
                let char = String(remaining.removeFirst())
                if let tokenID = tokenToID[char] {
                    tokens.append(tokenID)
                } else {
                    // Use UNK token
                    tokens.append(NLLBSpecialTokens.unkID)
                }
            }
        }
        
        return tokens
    }
    
    // MARK: - Decoding
    
    /// Decode token IDs to text
    ///
    /// - Parameter tokenIds: Array of token IDs to decode
    /// - Returns: Decoded text string
    /// - Throws: `NLLBTokenizerError` if decoding fails
    public func decode(_ tokenIds: [Int32]) throws -> String {
        guard isLoaded else {
            throw NLLBTokenizerError.decodingFailed(reason: "Vocabulary not loaded")
        }
        
        var result = ""
        
        for tokenID in tokenIds {
            // Skip special tokens
            if tokenID == NLLBSpecialTokens.bosID ||
               tokenID == NLLBSpecialTokens.eosID ||
               tokenID == NLLBSpecialTokens.padID {
                continue
            }
            
            // Skip language code tokens
            if languageCodeIDs.values.contains(tokenID) {
                continue
            }
            
            guard let token = idToToken[tokenID] else {
                // Unknown token, skip
                continue
            }
            
            // Handle SentencePiece word boundary marker (▁)
            if token.hasPrefix("▁") {
                result += " " + String(token.dropFirst())
            } else {
                result += token
            }
        }
        
        // Clean up leading/trailing whitespace
        return result.trimmingCharacters(in: .whitespaces)
    }
    
    // MARK: - Attention Mask
    
    /// Create attention mask for encoder input
    ///
    /// - Parameter tokenIds: Token IDs to create mask for
    /// - Returns: Attention mask (1 for valid tokens, 0 for padding)
    public func createAttentionMask(for tokenIds: [Int32]) -> [Int32] {
        return tokenIds.map { $0 == NLLBSpecialTokens.padID ? 0 : 1 }
    }
    
    /// Pad token sequence to specified length
    ///
    /// - Parameters:
    ///   - tokenIds: Token IDs to pad
    ///   - length: Target length
    /// - Returns: Padded token IDs
    public func pad(_ tokenIds: [Int32], to length: Int) -> [Int32] {
        if tokenIds.count >= length {
            return Array(tokenIds.prefix(length))
        }
        
        var padded = tokenIds
        let paddingCount = length - tokenIds.count
        padded.append(contentsOf: Array(repeating: NLLBSpecialTokens.padID, count: paddingCount))
        return padded
    }
    
    // MARK: - Utility
    
    /// Get vocabulary size
    public var vocabularySize: Int {
        return tokenToID.count
    }
    
    /// Check if a token exists in vocabulary
    public func contains(token: String) -> Bool {
        return tokenToID[token] != nil
    }
    
    /// Get token ID for a specific token string
    public func tokenID(for token: String) -> Int32? {
        return tokenToID[token]
    }
    
    /// Get token string for a specific ID
    public func token(for id: Int32) -> String? {
        return idToToken[id]
    }
}
