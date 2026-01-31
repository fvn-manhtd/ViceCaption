//
//  NLLBTranslationServiceTests.swift
//  VibeCaptionTests
//
//  Integration tests for NLLBTranslationService.
//

import XCTest
@testable import VibeCaption

final class NLLBTranslationServiceTests: XCTestCase {
    
    var modelManager: ModelManager!
    var service: NLLBTranslationService!
    var settingsManager: SettingsManager!
    var tempStorageURL: URL!
    
    // MARK: - Setup/Teardown
    
    override func setUpWithError() throws {
        // Setup temp storage
        tempStorageURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempStorageURL, withIntermediateDirectories: true)
        
        let defaults = UserDefaults(suiteName: "NLLBTests")!
        defaults.removePersistentDomain(forName: "NLLBTests")
        
        settingsManager = SettingsManager(userDefaults: defaults)
        settingsManager.modelStoragePath = tempStorageURL.path
        
        modelManager = ModelManager(settingsManager: settingsManager)
        modelManager.loadModelCatalog()
        
        service = NLLBTranslationService(modelManager: modelManager)
    }
    
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempStorageURL)
        if let defaults = UserDefaults(suiteName: "NLLBTests") {
            defaults.removePersistentDomain(forName: "NLLBTests")
        }
    }
    
    // MARK: - Model Loading Tests
    
    func testLoadModel_MissingModel_Throws() async {
        // Model files don't exist in temp directory
        do {
            try await service.loadModel()
            XCTFail("Should throw when model is missing")
        } catch let error as VibeCaptionError {
            switch error {
            case .modelMissing:
                // Success - expected error
                break
            default:
                XCTFail("Unexpected VibeCaptionError: \(error)")
            }
        } catch {
            // Also acceptable: ModelError.modelNotFound
            XCTAssertTrue(error is ModelError || error is VibeCaptionError,
                         "Unexpected error type: \(error)")
        }
    }
    
    func testLoadModel_InvalidModelFile_Throws() async throws {
        // 1. Create fake model directory structure
        let modelPath = tempStorageURL.appendingPathComponent("nllb-200-distilled/1.0")
        try FileManager.default.createDirectory(at: modelPath, withIntermediateDirectories: true)
        
        // 2. Create invalid encoder model file
        let encoderPath = modelPath.appendingPathComponent("NLLB_Encoder.mlmodelc")
        try "invalid model content".write(to: encoderPath, atomically: true, encoding: .utf8)
        
        // 3. Create invalid decoder model file  
        let decoderPath = modelPath.appendingPathComponent("NLLB_Decoder.mlmodelc")
        try "invalid model content".write(to: decoderPath, atomically: true, encoding: .utf8)
        
        // 4. Try loading
        do {
            try await service.loadModel()
            XCTFail("Should throw on invalid model file")
        } catch let error as VibeCaptionError {
            switch error {
            case .coreMLLoadFailed:
                // Success - expected error
                break
            case .modelMissing:
                // Also acceptable if the invalid file is treated as missing
                break
            default:
                XCTFail("Wrong VibeCaptionError: \(error)")
            }
        } catch {
            // CoreML load errors are expected
            XCTAssertTrue(true, "CoreML load error is expected for invalid files")
        }
    }
    
    // MARK: - Translation Tests (Model Not Loaded)
    
    func testTranslate_ModelNotLoaded_Throws() async {
        do {
            let _ = try await service.translate("こんにちは", from: .japanese, to: .english)
            XCTFail("Should throw if model not loaded")
        } catch let error as NLLBTranslationError {
            XCTAssertEqual(error, NLLBTranslationError.modelNotLoaded)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testIsModelLoaded_InitiallyFalse() async {
        let loaded = await service.isModelLoaded
        XCTAssertFalse(loaded)
    }
    
    // MARK: - Factory Tests
    
    func testFactory_WithMock_ReturnsMockService() {
        let factory = TranslationServiceFactory.shared
        let mockService = factory.getService(useMock: true)
        XCTAssertTrue(mockService is MockTranslationService)
    }
    
    func testFactory_WithoutModelManager_ReturnsMock() {
        let factory = TranslationServiceFactory.shared
        let service = factory.getService(useMock: false, modelManager: nil)
        XCTAssertTrue(service is MockTranslationService)
    }
    
    func testFactory_WithModelManager_ReturnsNLLBService() {
        let factory = TranslationServiceFactory.shared
        let service = factory.getService(useMock: false, modelManager: modelManager)
        XCTAssertTrue(service is NLLBTranslationService)
    }
    
    func testFactory_GetNLLBService_ReturnsCorrectType() {
        let factory = TranslationServiceFactory()
        let service = factory.getNLLBService(modelManager: modelManager)
        XCTAssertNotNil(service)
    }
    
    func testFactory_GetMockService_ReturnsCorrectType() {
        let factory = TranslationServiceFactory()
        let service = factory.getMockService()
        XCTAssertNotNil(service)
    }
}

// MARK: - Tokenizer Tests

final class NLLBTokenizerTests: XCTestCase {
    
    var tokenizer: NLLBTokenizer!
    var tempVocabURL: URL!
    
    override func setUpWithError() throws {
        tokenizer = NLLBTokenizer()
        tempVocabURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_vocab.json")
    }
    
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempVocabURL)
    }
    
    // MARK: - Vocabulary Loading Tests
    
    func testLoadVocabulary_ValidJSON_Success() throws {
        // Create a simple vocabulary JSON
        let vocab: [String: Int] = [
            "<s>": 0,
            "<pad>": 1,
            "</s>": 2,
            "<unk>": 3,
            "jpn_Jpan": 256001,
            "eng_Latn": 256002,
            "hello": 100,
            "world": 101,
            "▁hello": 102,
            "▁world": 103
        ]
        
        // Add enough tokens to pass validation
        var fullVocab = vocab
        for i in 4..<200 {
            fullVocab["token_\(i)"] = i
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: fullVocab)
        try jsonData.write(to: tempVocabURL)
        
        XCTAssertNoThrow(try tokenizer.loadVocabulary(from: tempVocabURL))
        XCTAssertTrue(tokenizer.isLoaded)
        XCTAssertGreaterThan(tokenizer.vocabularySize, 100)
    }
    
    func testLoadVocabulary_FileNotFound_Throws() {
        let nonExistentURL = URL(fileURLWithPath: "/nonexistent/path/vocab.json")
        
        XCTAssertThrowsError(try tokenizer.loadVocabulary(from: nonExistentURL)) { error in
            XCTAssertTrue(error is NLLBTokenizerError)
            if case NLLBTokenizerError.vocabularyNotFound = error {
                // Success
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    func testLoadVocabulary_InvalidFormat_Throws() throws {
        // Create invalid JSON (too few tokens)
        let invalidVocab: [String: Int] = ["a": 0, "b": 1]
        let jsonData = try JSONSerialization.data(withJSONObject: invalidVocab)
        try jsonData.write(to: tempVocabURL)
        
        XCTAssertThrowsError(try tokenizer.loadVocabulary(from: tempVocabURL)) { error in
            XCTAssertTrue(error is NLLBTokenizerError)
        }
    }
    
    // MARK: - Encoding Tests
    
    func testEncode_VocabularyNotLoaded_Throws() {
        XCTAssertThrowsError(try tokenizer.encode("test", sourceLanguage: .japanese, targetLanguage: .english)) { error in
            XCTAssertTrue(error is NLLBTokenizerError)
            if case NLLBTokenizerError.encodingFailed = error {
                // Success
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    // MARK: - Decoding Tests
    
    func testDecode_VocabularyNotLoaded_Throws() {
        XCTAssertThrowsError(try tokenizer.decode([1, 2, 3])) { error in
            XCTAssertTrue(error is NLLBTokenizerError)
            if case NLLBTokenizerError.decodingFailed = error {
                // Success
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    // MARK: - Attention Mask Tests
    
    func testCreateAttentionMask_ValidTokens() {
        let tokens: [Int32] = [100, 101, 102, 1, 1] // Last two are padding
        let mask = tokenizer.createAttentionMask(for: tokens)
        
        XCTAssertEqual(mask.count, tokens.count)
        XCTAssertEqual(mask[0], 1) // Valid token
        XCTAssertEqual(mask[1], 1) // Valid token
        XCTAssertEqual(mask[2], 1) // Valid token
        XCTAssertEqual(mask[3], 0) // Padding
        XCTAssertEqual(mask[4], 0) // Padding
    }
    
    // MARK: - Padding Tests
    
    func testPad_ShorterSequence() {
        let tokens: [Int32] = [1, 2, 3]
        let padded = tokenizer.pad(tokens, to: 5)
        
        XCTAssertEqual(padded.count, 5)
        XCTAssertEqual(padded, [1, 2, 3, 1, 1]) // 1 is padding token ID
    }
    
    func testPad_LongerSequence() {
        let tokens: [Int32] = [1, 2, 3, 4, 5, 6]
        let padded = tokenizer.pad(tokens, to: 4)
        
        XCTAssertEqual(padded.count, 4)
        XCTAssertEqual(padded, [1, 2, 3, 4])
    }
    
    // MARK: - Language Code Tests
    
    func testLanguageCode_Japanese() {
        XCTAssertEqual(NLLBLanguageCodes.japanese, "jpn_Jpan")
        XCTAssertEqual(NLLBLanguageCodes.code(for: .japanese), "jpn_Jpan")
    }
    
    func testLanguageCode_English() {
        XCTAssertEqual(NLLBLanguageCodes.english, "eng_Latn")
        XCTAssertEqual(NLLBLanguageCodes.code(for: .english), "eng_Latn")
    }
    
    // MARK: - Special Tokens Tests
    
    func testSpecialTokens_IDs() {
        XCTAssertEqual(NLLBSpecialTokens.bosID, 0)
        XCTAssertEqual(NLLBSpecialTokens.padID, 1)
        XCTAssertEqual(NLLBSpecialTokens.eosID, 2)
        XCTAssertEqual(NLLBSpecialTokens.unkID, 3)
    }
    
    func testSpecialTokens_Strings() {
        XCTAssertEqual(NLLBSpecialTokens.bos, "<s>")
        XCTAssertEqual(NLLBSpecialTokens.pad, "<pad>")
        XCTAssertEqual(NLLBSpecialTokens.eos, "</s>")
        XCTAssertEqual(NLLBSpecialTokens.unk, "<unk>")
    }
}

// MARK: - Error Equatable Conformance for Testing

extension NLLBTranslationError: Equatable {
    public static func == (lhs: NLLBTranslationError, rhs: NLLBTranslationError) -> Bool {
        switch (lhs, rhs) {
        case (.modelNotLoaded, .modelNotLoaded):
            return true
        case (.invalidModelOutput, .invalidModelOutput):
            return true
        case (.maxLengthExceeded, .maxLengthExceeded):
            return true
        case (.encoderInferenceFailed, .encoderInferenceFailed):
            return true
        case (.decoderInferenceFailed, .decoderInferenceFailed):
            return true
        case (.tokenizationFailed, .tokenizationFailed):
            return true
        default:
            return false
        }
    }
}

// NOTE: Full translation tests require a valid NLLB CoreML model (~600MB+).
// These are best run as integration tests or manually verified during development.
//
// Example manual test cases:
// - "こんにちは" → "Hello"
// - "ありがとうございます" → "Thank you very much"
// - "今日はいい天気です" → "The weather is nice today"
// - Long text (>100 chars) → Verify truncation/output
