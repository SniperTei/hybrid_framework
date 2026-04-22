import Foundation

public struct ErrorCode {
    public static let SUCCESS = "000000"

    // Standard errors (100001-100005)
    public static let PARSE_ERROR = "100001"
    public static let INVALID_REQUEST = "100002"
    public static let METHOD_NOT_FOUND = "100003"
    public static let INVALID_PARAMS = "100004"
    public static let INTERNAL_ERROR = "100005"

    // Business errors (200001-200009)
    public static let UNKNOWN_COMPONENT = "200001"
    public static let UNKNOWN_FUNCTION = "200002"
    public static let PERMISSION_DENIED = "200003"
    public static let TIMEOUT = "200004"
    public static let CANCELLED = "200005"
    public static let DOMAIN_NOT_ALLOWED = "200006"
    public static let PARAM_VALIDATION_FAILED = "200007"
    public static let COMPONENT_NOT_INITIALIZED = "200008"
    public static let RATE_LIMIT_EXCEEDED = "200009"

    // Security errors (300001-300004)
    public static let SIGNATURE_INVALID = "300001"
    public static let SIGNATURE_EXPIRED = "300002"
    public static let NONCE_REUSED = "300003"
    public static let BRIDGE_TOKEN_INVALID = "300004"

    public static func getDescription(_ code: String) -> String {
        switch code {
        case PARSE_ERROR: return "Parse error"
        case INVALID_REQUEST: return "Invalid request"
        case METHOD_NOT_FOUND: return "Method not found"
        case INVALID_PARAMS: return "Invalid params"
        case INTERNAL_ERROR: return "Internal error"
        case UNKNOWN_COMPONENT: return "Unknown component"
        case UNKNOWN_FUNCTION: return "Unknown function"
        case PERMISSION_DENIED: return "Permission denied"
        case TIMEOUT: return "Request timeout"
        case CANCELLED: return "Request cancelled"
        case DOMAIN_NOT_ALLOWED: return "Domain not allowed"
        case PARAM_VALIDATION_FAILED: return "Parameter validation failed"
        case COMPONENT_NOT_INITIALIZED: return "Component not initialized"
        case RATE_LIMIT_EXCEEDED: return "Rate limit exceeded"
        case SIGNATURE_INVALID: return "Signature invalid"
        case SIGNATURE_EXPIRED: return "Signature expired"
        case NONCE_REUSED: return "Nonce reused"
        case BRIDGE_TOKEN_INVALID: return "Bridge token invalid"
        default: return "Unknown error"
        }
    }
}
