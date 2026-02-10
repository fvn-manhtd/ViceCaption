//
//  NLLBTranslationService.swift
//  VibeCaption
//
//  Real implementation of TranslationServiceProtocol using NLLB-200 CoreML model.
//

import Foundation
import CoreML
import os.log

// MARK: - NLLB Translation Error

public enum NLLBTranslationError: Error, LocalizedError {
    case modelNotLoaded
    case encoderInferenceFailed(Error)
    case decoderInferenceFailed(Error)
    case tokenizationFailed(Error)
    case invalidModelOutput
    case maxLengthExceeded
    
    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "NLLB translation model is not loaded"
        case .encoderInferenceFailed(let error):
            return "Encoder inference failed: \(error.localizedDescription)"
        case .decoderInferenceFailed(let error):
            return "Decoder inference failed: \(error.localizedDescription)"
        case .tokenizationFailed(let error):
            return "Tokenization failed: \(error.localizedDescription)"
        case .invalidModelOutput:
            return "Invalid model output format"
        case .maxLengthExceeded:
            return "Input text exceeds maximum supported length"
        }
    }
}

// MARK: - NLLB Translation Service

/// Real implementation of TranslationServiceProtocol using NLLB-200 CoreML model.
///
/// This service loads the NLLB-200 distilled model converted to CoreML format
/// and performs on-device Japanese to English translation.
///
/// The model consists of:
/// - Encoder: Processes source language input
/// - Decoder: Generates target language output autoregressively
///
/// Example:
/// ```swift
/// let service = NLLBTranslationService(modelManager: modelManager)
/// try await service.loadModel()
/// let result = try await service.translate("こんにちは", from: .japanese, to: .english)
/// print(result.translatedText) // "Hello"
/// ```
final class NLLBTranslationService: TranslationServiceProtocol {
    
    // MARK: - Properties
    
    private let modelManager: ModelManager
    private var encoder: MLModel?
    private var decoder: MLModel?
    private var tokenizer: NLLBTokenizer?
    
    private(set) var isModelLoaded: Bool = false
    
    /// Maximum output tokens for decoder
    private let maxOutputTokens: Int = 128
    
    /// Configuration for CoreML model
    private var modelConfiguration: MLModelConfiguration {
        let config = MLModelConfiguration()
        config.computeUnits = .all  // Use ANE/GPU when available
        return config
    }
    
    /// Preferred model IDs for looking up in ModelManager (high quality first).
    private let preferredModelIDs = [
        "nllb-200-600m-optional",
        "nllb-200-distilled"
    ]
    
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.vibecaption",
        category: "NLLBTranslationService"
    )
    
    // MARK: - Initialization
    
    init(modelManager: ModelManager) {
        self.modelManager = modelManager
    }
    
    // MARK: - TranslationServiceProtocol
    
    func loadModel() async throws {
        // Prevent reloading if already loaded
        guard !isModelLoaded else { return }

        // 1. Get model info from ModelManager
        guard let modelInfo = resolveTranslationModelInfo() else {
            logger.error("NLLB model not found in catalog")
            throw VibeCaptionError.modelMissing(modelName: "NLLB-200")
        }

        guard let modelPath = modelManager.getModelPath(for: modelInfo) else {
            logger.error("Could not get model path for: \(modelInfo.id)")
            throw VibeCaptionError.modelMissing(modelName: "NLLB-200")
        }

        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: modelPath.path) else {
            logger.error("NLLB model directory not found at: \(modelPath.path)")
            throw VibeCaptionError.modelMissing(modelName: "NLLB-200")
        }

        let encoderCandidates = ["NLLB_Encoder.mlmodelc", "NLLB_Encoder.mlpackage"]
        let decoderCandidates = ["NLLB_Decoder.mlmodelc", "NLLB_Decoder.mlpackage"]
        let vocabCandidates = ["tokenizer.json", "vocab.json", "sentencepiece.bpe.model", "tokenizer.model"]

        guard let actualEncoderPath = resolveArtifact(
            namedAnyOf: encoderCandidates,
            under: modelPath,
            fileManager: fileManager
        ) else {
            if hasUnsupportedPyTorchArtifact(in: modelPath, fileManager: fileManager) {
                throw VibeCaptionError.coreMLLoadFailed(
                    modelName: "NLLB-200",
                    reason: "Found pytorch_model.bin only. Install CoreML artifacts (NLLB_Encoder/NLLB_Decoder + tokenizer)."
                )
            }
            logger.error("Encoder model not found in: \(modelPath.path)")
            throw VibeCaptionError.modelMissing(modelName: "NLLB-200 Encoder")
        }

        guard let actualDecoderPath = resolveArtifact(
            namedAnyOf: decoderCandidates,
            under: modelPath,
            fileManager: fileManager
        ) else {
            logger.error("Decoder model not found in: \(modelPath.path)")
            throw VibeCaptionError.modelMissing(modelName: "NLLB-200 Decoder")
        }

        guard let tokenizerPath = resolveArtifact(
            namedAnyOf: vocabCandidates,
            under: modelPath,
            fileManager: fileManager
        ) else {
            logger.error("Tokenizer file not found in: \(modelPath.path)")
            throw VibeCaptionError.modelMissing(modelName: "NLLB-200 Tokenizer")
        }
        
        logger.info("Loading NLLB-200 models from: \(modelPath.path)")
        
        do {
            // 2. Load tokenizer
            let loadedTokenizer = NLLBTokenizer()

            if tokenizerPath.pathExtension == "model" {
                try loadedTokenizer.loadSentencePieceModel(from: tokenizerPath)
            } else {
                try loadedTokenizer.loadVocabulary(from: tokenizerPath)
            }
            logger.info("Loaded vocabulary from: \(tokenizerPath.path)")
            
            // 3. Load CoreML models
            let loadedEncoder = try MLModel(contentsOf: actualEncoderPath, configuration: modelConfiguration)
            logger.info("Encoder model loaded successfully")
            
            let loadedDecoder = try MLModel(contentsOf: actualDecoderPath, configuration: modelConfiguration)
            logger.info("Decoder model loaded successfully")
            
            // Store references
            self.encoder = loadedEncoder
            self.decoder = loadedDecoder
            self.tokenizer = loadedTokenizer
            self.isModelLoaded = true
            
            logger.info("NLLB-200 translation model loaded successfully")
            
        } catch let error as VibeCaptionError {
            throw error
        } catch {
            logger.error("Failed to load NLLB model: \(error.localizedDescription)")
            throw VibeCaptionError.coreMLLoadFailed(modelName: "NLLB-200", reason: error.localizedDescription)
        }
    }

    private func resolveTranslationModelInfo() -> ModelInfo? {
        let fileManager = FileManager.default

        for modelID in preferredModelIDs {
            if let model = modelManager.getModel(id: modelID),
               let modelPath = modelManager.getModelPath(for: model),
               fileManager.fileExists(atPath: modelPath.path) {
                return model
            }
        }

        return modelManager.models.first(where: { model in
            guard model.id.localizedCaseInsensitiveContains("nllb"),
                  let modelPath = modelManager.getModelPath(for: model) else {
                return false
            }
            return fileManager.fileExists(atPath: modelPath.path)
        }) ?? modelManager.models.first(where: { $0.id.localizedCaseInsensitiveContains("nllb") })
    }

    private func resolveArtifact(
        namedAnyOf names: [String],
        under root: URL,
        fileManager: FileManager
    ) -> URL? {
        for name in names {
            let directPath = root.appendingPathComponent(name)
            if fileManager.fileExists(atPath: directPath.path) {
                return directPath
            }
        }

        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for case let url as URL in enumerator {
            if names.contains(url.lastPathComponent) {
                return url
            }
        }

        return nil
    }

    private func hasUnsupportedPyTorchArtifact(in root: URL, fileManager: FileManager) -> Bool {
        resolveArtifact(namedAnyOf: ["pytorch_model.bin"], under: root, fileManager: fileManager) != nil
    }
    
    func unloadModel() {
        performUnload()
    }
    
    private func performUnload() {
        encoder = nil
        decoder = nil
        tokenizer = nil
        isModelLoaded = false
        logger.info("NLLB-200 model unloaded")
    }
    
    func translate(_ text: String, from sourceLanguage: Language, to targetLanguage: Language) async throws -> TranslationResult {
        let startTime = Date()
        
        guard isModelLoaded, let encoder = encoder, let decoder = decoder, let tokenizer = tokenizer else {
            throw NLLBTranslationError.modelNotLoaded
        }
        
        // Skip empty text
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return TranslationResult(
                originalText: text,
                translatedText: "",
                confidence: 1.0,
                processingTime: 0,
                targetLanguage: targetLanguage
            )
        }
        
        logger.debug("Translating: \(text.prefix(50))...")
        
        do {
            // 1. Tokenize input
            let inputTokens = try tokenizer.encode(text, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
            let attentionMask = tokenizer.createAttentionMask(for: inputTokens)
            
            logger.debug("Input tokens: \(inputTokens.count)")
            
            // 2. Run encoder
            let encoderOutput = try await runEncoder(
                inputIDs: inputTokens,
                attentionMask: attentionMask,
                encoder: encoder
            )
            
            // 3. Run decoder (autoregressive generation)
            let decoderInput = try tokenizer.createDecoderInput(targetLanguage: targetLanguage)
            let outputTokens = try await generateOutput(
                encoderOutput: encoderOutput,
                encoderAttentionMask: attentionMask,
                initialDecoderInput: decoderInput,
                decoder: decoder
            )
            
            // 4. Decode output tokens to text
            let translatedText = try tokenizer.decode(outputTokens)
            
            let processingTime = Date().timeIntervalSince(startTime)
            
            logger.info("Translation completed in \(String(format: "%.2f", processingTime))s: \(translatedText.prefix(50))...")
            
            // Calculate confidence based on output length and processing time
            // This is a heuristic since NLLB doesn't provide direct confidence scores
            let confidence = calculateConfidence(
                inputLength: text.count,
                outputLength: translatedText.count,
                processingTime: processingTime
            )
            
            return TranslationResult(
                originalText: text,
                translatedText: translatedText,
                confidence: confidence,
                processingTime: processingTime,
                targetLanguage: targetLanguage
            )
            
        } catch let error as NLLBTokenizerError {
            throw NLLBTranslationError.tokenizationFailed(error)
        } catch let error as NLLBTranslationError {
            throw error
        } catch {
            throw VibeCaptionError.translationFailed(reason: error.localizedDescription)
        }
    }
    
    // MARK: - Encoder
    
    private func runEncoder(
        inputIDs: [Int32],
        attentionMask: [Int32],
        encoder: MLModel
    ) async throws -> MLMultiArray {
        // Prepare input tensors
        let sequenceLength = inputIDs.count
        
        // Create MLMultiArray for input_ids
        let inputIDsArray = try MLMultiArray(shape: [1, NSNumber(value: sequenceLength)], dataType: .int32)
        for (i, token) in inputIDs.enumerated() {
            inputIDsArray[[0, NSNumber(value: i)]] = NSNumber(value: token)
        }
        
        // Create MLMultiArray for attention_mask
        let attentionMaskArray = try MLMultiArray(shape: [1, NSNumber(value: sequenceLength)], dataType: .int32)
        for (i, mask) in attentionMask.enumerated() {
            attentionMaskArray[[0, NSNumber(value: i)]] = NSNumber(value: mask)
        }
        
        // Create feature provider
        let inputFeatures = try MLDictionaryFeatureProvider(dictionary: [
            "input_ids": MLFeatureValue(multiArray: inputIDsArray),
            "attention_mask": MLFeatureValue(multiArray: attentionMaskArray)
        ])
        
        // Run inference
        let output = try encoder.prediction(from: inputFeatures)
        
        // Extract encoder hidden states
        guard let hiddenStates = output.featureValue(for: "last_hidden_state")?.multiArrayValue else {
            throw NLLBTranslationError.invalidModelOutput
        }
        
        return hiddenStates
    }
    
    // MARK: - Decoder (Autoregressive Generation)
    
    private func generateOutput(
        encoderOutput: MLMultiArray,
        encoderAttentionMask: [Int32],
        initialDecoderInput: [Int32],
        decoder: MLModel
    ) async throws -> [Int32] {
        var generatedTokens = initialDecoderInput
        var isComplete = false
        
        let maskLength = encoderAttentionMask.count
        let encoderMaskArray = try MLMultiArray(shape: [1, NSNumber(value: maskLength)], dataType: .int32)
        for (i, mask) in encoderAttentionMask.enumerated() {
            encoderMaskArray[[0, NSNumber(value: i)]] = NSNumber(value: mask)
        }
        
        // Autoregressive generation loop
        for step in 0..<maxOutputTokens {
            // Prepare decoder input
            let decoderLength = generatedTokens.count
            let decoderInputArray = try MLMultiArray(shape: [1, NSNumber(value: decoderLength)], dataType: .int32)
            for (i, token) in generatedTokens.enumerated() {
                decoderInputArray[[0, NSNumber(value: i)]] = NSNumber(value: token)
            }
            
            // Create decoder attention mask (all 1s for generated tokens)
            let decoderMaskArray = try MLMultiArray(shape: [1, NSNumber(value: decoderLength)], dataType: .int32)
            for i in 0..<decoderLength {
                decoderMaskArray[[0, NSNumber(value: i)]] = 1
            }
            
            // Prepare input features
            let decoderInputFeatures = try MLDictionaryFeatureProvider(dictionary: [
                "input_ids": MLFeatureValue(multiArray: decoderInputArray),
                "attention_mask": MLFeatureValue(multiArray: decoderMaskArray),
                "encoder_hidden_states": MLFeatureValue(multiArray: encoderOutput),
                "encoder_attention_mask": MLFeatureValue(multiArray: encoderMaskArray)
            ])
            
            // Run decoder
            let decoderOutput = try decoder.prediction(from: decoderInputFeatures)
            
            // Get logits for the last position
            guard let logits = decoderOutput.featureValue(for: "logits")?.multiArrayValue else {
                throw NLLBTranslationError.invalidModelOutput
            }
            
            // Get the next token (greedy decoding - take argmax)
            let nextToken = try getNextToken(logits: logits, position: decoderLength - 1)
            
            // Check for EOS token
            if nextToken == NLLBSpecialTokens.eosID {
                isComplete = true
                break
            }
            
            generatedTokens.append(nextToken)
            
            // Safety check for very long outputs
            if step >= maxOutputTokens - 1 {
                logger.warning("Reached maximum output length")
                break
            }
        }
        
        if !isComplete {
            logger.debug("Generation ended without EOS token")
        }
        
        return generatedTokens
    }
    
    /// Get the next token using greedy decoding (argmax)
    private func getNextToken(logits: MLMultiArray, position: Int) throws -> Int32 {
        // Logits shape is typically [batch_size, sequence_length, vocab_size]
        // We want the last position's logits
        
        let shape = logits.shape
        guard shape.count >= 2 else {
            throw NLLBTranslationError.invalidModelOutput
        }
        
        let vocabSize: Int
        let positionToUse: Int
        
        if shape.count == 3 {
            // Shape: [1, seq_len, vocab_size]
            vocabSize = shape[2].intValue
            positionToUse = position
        } else {
            // Shape: [1, vocab_size] - already just last position
            vocabSize = shape[1].intValue
            positionToUse = 0
        }
        
        var maxValue: Float = -.greatestFiniteMagnitude
        var maxIndex: Int32 = 0
        
        // Find argmax
        for vocabIdx in 0..<vocabSize {
            let value: Float
            if shape.count == 3 {
                value = logits[[0, NSNumber(value: positionToUse), NSNumber(value: vocabIdx)]].floatValue
            } else {
                value = logits[[0, NSNumber(value: vocabIdx)]].floatValue
            }
            
            if value > maxValue {
                maxValue = value
                maxIndex = Int32(vocabIdx)
            }
        }
        
        return maxIndex
    }
    
    // MARK: - Confidence Calculation
    
    /// Calculate a confidence score based on translation characteristics
    private func calculateConfidence(inputLength: Int, outputLength: Int, processingTime: TimeInterval) -> Double {
        // Heuristic-based confidence:
        // - Reasonable output/input ratio for JA->EN translation
        // - Fast processing time indicates certainty
        
        let lengthRatio = Double(outputLength) / Double(max(inputLength, 1))
        
        // For JA->EN, English output is typically longer than Japanese input
        // Reasonable ratio is 0.5 to 3.0
        var confidence = 0.9
        
        if lengthRatio < 0.3 || lengthRatio > 5.0 {
            confidence -= 0.2 // Unusual ratio
        }
        
        if processingTime > 5.0 {
            confidence -= 0.1 // Very slow processing
        }
        
        if outputLength == 0 {
            confidence = 0.3 // Empty output
        }
        
        return max(0.3, min(1.0, confidence))
    }
}
