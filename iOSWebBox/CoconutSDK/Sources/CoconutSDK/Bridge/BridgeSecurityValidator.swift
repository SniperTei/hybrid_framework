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

public class BridgeSecurityValidator: @unchecked Sendable {

    private let tag = "BridgeSecurity"

    // All mutable state guarded by `lock` so the validator is safe to call from
    // any thread. Configuration reads (maxParamsSize etc.) are intentionally
    // also locked because callers may mutate them at runtime.
    private let lock = NSLock()
    private var _allowedDomains: Set<String> = []
    private var _callCounts: [String: Int] = [:]
    private var _lastResetTime: Int64 = Int64(Date().timeIntervalSince1970 * 1000)

    private var _maxParamsSize: Int = 1_048_576 // 1MB
    private var _rateLimitPerMethod: Int = 100
    private var _rateLimitWindowMs: Int64 = 60_000 // 1 minute

    public var maxParamsSize: Int {
        get { lock.lock(); defer { lock.unlock() }; return _maxParamsSize }
        set { lock.lock(); defer { lock.unlock() }; _maxParamsSize = newValue }
    }
    public var rateLimitPerMethod: Int {
        get { lock.lock(); defer { lock.unlock() }; return _rateLimitPerMethod }
        set { lock.lock(); defer { lock.unlock() }; _rateLimitPerMethod = newValue }
    }
    public var rateLimitWindowMs: Int64 {
        get { lock.lock(); defer { lock.unlock() }; return _rateLimitWindowMs }
        set { lock.lock(); defer { lock.unlock() }; _rateLimitWindowMs = newValue }
    }

    public func addAllowedDomain(_ domain: String) {
        lock.lock(); defer { lock.unlock() }
        _allowedDomains.insert(domain)
    }

    public func setAllowedDomains(_ domains: [String]) {
        lock.lock(); defer { lock.unlock() }
        _allowedDomains = Set(domains)
    }

    /// Returns the currently configured allowed domains (snapshot under lock).
    public func getAllowedDomains() -> [String] {
        lock.lock(); defer { lock.unlock() }
        return Array(_allowedDomains)
    }

    public func validateDomain(_ url: String) -> SecurityResult {
        let domains = { () -> Set<String> in
            lock.lock(); defer { lock.unlock() }
            return _allowedDomains
        }()

        if domains.isEmpty { return .valid }

        guard let host = extractHost(url), !host.isEmpty else {
            return .invalid("Cannot extract host from URL: \(url)")
        }

        let isAllowed = domains.contains { domain in
            host == domain || host.hasSuffix(".\(domain)")
        }

        if isAllowed {
            return .valid
        } else {
            return .invalid("Domain not allowed: \(host)")
        }
    }

    public func validateParamsSize(_ json: String) -> SecurityResult {
        let limit = { () -> Int in
            lock.lock(); defer { lock.unlock() }
            return _maxParamsSize
        }()
        if json.utf8.count > limit {
            return .invalid("Params size exceeds limit (\(json.utf8.count) > \(limit))")
        }
        return .valid
    }

    public func checkRateLimit(_ method: String) -> SecurityResult {
        lock.lock(); defer { lock.unlock() }

        resetIfNeededLocked()

        let count = _callCounts[method, default: 0]
        if count >= _rateLimitPerMethod {
            return .invalid("Rate limit exceeded for method: \(method)")
        }

        _callCounts[method] = count + 1
        return .valid
    }

    private func extractHost(_ url: String) -> String? {
        guard let urlObj = URL(string: url) else { return nil }
        return urlObj.host
    }

    /// Must be called while holding `lock`.
    private func resetIfNeededLocked() {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        if now - _lastResetTime >= _rateLimitWindowMs {
            _callCounts.removeAll()
            _lastResetTime = now
        }
    }

    /// Test/support hook: clears rate-limit counters and resets the window.
    public func resetRateLimit() {
        lock.lock(); defer { lock.unlock() }
        _callCounts.removeAll()
        _lastResetTime = Int64(Date().timeIntervalSince1970 * 1000)
    }
}
