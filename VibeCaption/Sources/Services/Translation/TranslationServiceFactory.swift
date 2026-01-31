import Foundation

public class TranslationServiceFactory {
    public static let shared = TranslationServiceFactory()
    
    // Private init to enforce singleton usage if desired, though public init is also fine.
    // Making it public to allow creating instances if needed, but shared covers most cases.
    public init() {}
    
    public func getService(useMock: Bool) -> TranslationServiceProtocol {
        if useMock {
            return MockTranslationService()
        }
        
        #if DEBUG
        // In DEBUG builds without explicit mock request, we might still want default behavior.
        // But the requirement says "Returns mock in debug/test, real in production".
        // Assuming this means if useMock is NOT specified, we check environment.
        // However, the signature is `getService(useMock: Bool)`.
        // If the caller explicitly passes `false` (real), and we are in DEBUG, ideally we return Real if possible.
        // Since Real isn't implemented, we will return Mock with a log warning or fatalError depending on preference.
        // For now, I will fallback to Mock with a TODO note.
        print("Warning: Real TranslationService not implemented yet. Returning Mock.")
        return MockTranslationService()
        #else
        // Production
        // TODO: Implement RealTranslationService
        print("Warning: Real TranslationService not implemented yet. Returning Mock.")
        return MockTranslationService()
        #endif
    }
}
