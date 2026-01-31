import Foundation

public enum Language: String, CaseIterable, Codable {
    case english = "en"
    case japanese = "ja"
    
    // Extensible for future languages
    // case other = "code"

    public var code: String {
        return self.rawValue
    }
    
    public var displayName: String {
        switch self {
        case .english: return "English"
        case .japanese: return "Japanese"
        }
    }
}
