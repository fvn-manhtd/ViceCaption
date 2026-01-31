import Foundation

public class TranslationServiceFactory {
    public static let shared = TranslationServiceFactory()
    
    // Private init to enforce singleton usage if desired, though public init is also fine.
    // Making it public to allow creating instances if needed, but shared covers most cases.
    public init() {}
    
    /// Get a translation service instance
    ///
    /// - Parameters:
    ///   - useMock: If true, returns a MockTranslationService
    ///   - modelManager: Optional ModelManager for real service. Required when useMock is false.
    /// - Returns: A TranslationServiceProtocol implementation
    public func getService(useMock: Bool, modelManager: ModelManager? = nil) -> TranslationServiceProtocol {
        if useMock {
            return MockTranslationService()
        }
        
        // Real service requires ModelManager
        guard let manager = modelManager else {
            #if DEBUG
            print("Warning: ModelManager not provided for real TranslationService. Returning Mock.")
            #endif
            return MockTranslationService()
        }
        
        return NLLBTranslationService(modelManager: manager)
    }
    
    /// Convenience method for getting mock service (for testing)
    public func getMockService(config: MockTranslationService.Configuration = .default) -> MockTranslationService {
        return MockTranslationService(config: config)
    }
    
    /// Convenience method for getting real NLLB service
    public func getNLLBService(modelManager: ModelManager) -> NLLBTranslationService {
        return NLLBTranslationService(modelManager: modelManager)
    }
}
