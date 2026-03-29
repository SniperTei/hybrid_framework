import Foundation

public enum Environment: String {
    case dev
    case test
    case staging
    case prod

    public var displayName: String {
        switch self {
        case .dev: return "Development"
        case .test: return "Testing"
        case .staging: return "Staging"
        case .prod: return "Production"
        }
    }

    public var defaultH5Domain: String {
        switch self {
        case .dev: return "http://192.168.3.49:5174"
        case .test: return "http://192.168.1.100:5174"
        case .staging: return "https://staging-h5.example.com"
        case .prod: return "https://h5.example.com"
        }
    }

    public var defaultApiDomain: String {
        switch self {
        case .dev: return "http://192.168.3.49:8080"
        case .test: return "http://192.168.1.100:8080"
        case .staging: return "https://staging-api.example.com"
        case .prod: return "https://api.example.com"
        }
    }

    public var isDebug: Bool {
        return self == .dev || self == .test
    }
}
