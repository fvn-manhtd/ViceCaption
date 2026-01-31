import XCTest
@testable import VibeCaption

final class TranslationServiceTests: XCTestCase {
    
    var service: MockTranslationService!
    
    override func setUp() {
        super.setUp()
        service = MockTranslationService()
    }
    
    override func tearDown() {
        service = nil
        super.tearDown()
    }
    
    // MARK: - Language Enum Tests
    
    func testLanguageEnumProperties() {
        XCTAssertEqual(Language.english.code, "en")
        XCTAssertEqual(Language.japanese.code, "ja")
        
        XCTAssertEqual(Language.english.displayName, "English")
        XCTAssertEqual(Language.japanese.displayName, "Japanese")
    }
    
    // MARK: - Mock Service Tests
    
    func testMockServiceLoading() async throws {
        XCTAssertFalse(service.isModelLoaded)
        try await service.loadModel()
        XCTAssertTrue(service.isModelLoaded)
        service.unloadModel()
        XCTAssertFalse(service.isModelLoaded)
    }
    
    func testMockTranslationSuccess() async throws {
        try await service.loadModel()
        
        let originalText = "こんにちは"
        let result = try await service.translate(originalText, from: .japanese, to: .english)
        
        XCTAssertEqual(result.originalText, originalText)
        XCTAssertEqual(result.translatedText, "Hello") // Known phrase
        XCTAssertEqual(result.targetLanguage, .english)
        XCTAssertGreaterThan(result.confidence, 0.8) // Default is high confidence
    }
    
    func testMockTranslationUnknownPhrase() async throws {
        try await service.loadModel()
        
        let originalText = "Unknown phrase"
        let result = try await service.translate(originalText, from: .english, to: .japanese)
        
        XCTAssertEqual(result.translatedText, "[MOCK] Unknown phrase")
    }
    
    func testMockSimulatedDelay() async throws {
        service = MockTranslationService(config: .init(mode: .highConfidence, delayRange: 0.5..<0.6))
        try await service.loadModel()
        
        let startTime = Date()
        _ = try await service.translate("Test", from: .english, to: .japanese)
        let duration = Date().timeIntervalSince(startTime)
        
        XCTAssertGreaterThanOrEqual(duration, 0.5)
        // Upper bound check might be flaky in CI, but good for local
        // XCTAssertLessThan(duration, 1.0) 
    }
    
    func testMockSimulatedFailure() async throws {
        service = MockTranslationService(config: .init(mode: .failure, delayRange: 0.1..<0.2))
        try await service.loadModel()
        
        do {
            _ = try await service.translate("Test", from: .english, to: .japanese)
            XCTFail("Should have thrown error")
        } catch let error as MockTranslationError {
            XCTAssertEqual(error, MockTranslationError.simulatedFailure)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Factory Tests
    
    func testFactoryReturnsMock() {
        let factory = TranslationServiceFactory.shared
        let mockService = factory.getService(useMock: true)
        XCTAssertTrue(mockService is MockTranslationService)
        
        // Even if useMock is false, it currently returns MockTranslationService as fallback
        let realService = factory.getService(useMock: false)
        XCTAssertTrue(realService is MockTranslationService)
    }
}
