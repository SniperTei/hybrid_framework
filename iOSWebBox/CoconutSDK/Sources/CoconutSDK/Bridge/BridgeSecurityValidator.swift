import Foundation

public enum SecurityResult {
    case valid
    case invalid(String)

    public var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    public var message: String {
        if case .invalid(let msg) = self { return msg }
        return ""
    }
}

public class BridgeSecurityValidator {

    private let tag = "BridgeSecurity"

    private var allowedDomains: Set<String> = []
    private var callCounts: [String: Int] = [:]
    private var lastResetTime: Int64 = Int64(Date().timeIntervalSince1970 * 1000)

    public var maxParamsSize: Int = 1_048_576 // 1MB
    public var rateLimitPerMethod: Int = 100
    public var rateLimitWindowMs: Int64 = 60_000 // 1 minute

    public func addAllowedDomain(_ domain: String) {
        allowedDomains.insert(domain)
    }

    public func setAllowedDomains(_ domains: [String]) {
        allowedDomains = Set(domains)
    }

    public func validateDomain(_ url: String) -> SecurityResult {
        if allowedDomains.isEmpty { return .valid }

        guard let host = extractHost(url), !host.isEmpty else {
            return .invalid("Cannot extract host from URL: \(url)")
        }

        let isAllowed = allowedDomains.contains { domain in
            host == domain || host.hasSuffix(".\(domain)")
        }

        if isAllowed {
            return .valid
        } else {
            return .invalid("Domain not allowed: \(host)")
        }
    }

    public func validateParamsSize(_ json: String) -> SecurityResult {
        if json.utf8.count > maxParamsSize {
            return .invalid("Params size exceeds limit (\(json.utf8.count) > \(maxParamsSize))")
        }
        return .valid
    }

    public func checkRateLimit(_ method: String) -> SecurityResult {
        resetIfNeeded()

        let count = callCounts[method, default: 0]
        if count >= rateLimitPerMethod {
            return .invalid("Rate limit exceeded for method: \(method)")
        }

        callCounts[method] = count + 1
        return .valid
    }

    private func extractHost(_ url: String) -> String? {
        guard let urlObj = URL(string: url) else { return nil }
        return urlObj.host
    }

    private func resetIfNeeded() {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        if now - lastResetTime >= rateLimitWindowMs {
            callCounts.removeAll()
            lastResetTime = now
        }
    }
}
