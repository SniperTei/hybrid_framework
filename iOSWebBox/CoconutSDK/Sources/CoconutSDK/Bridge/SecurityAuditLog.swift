import Foundation

public class SecurityAuditLog: @unchecked Sendable {

    public static let shared = SecurityAuditLog()
    private let tag = "SecurityAuditLog"

    public static let EVENT_DOMAIN_REJECTED = "DOMAIN_REJECTED"
    public static let EVENT_RATE_LIMITED = "RATE_LIMITED"
    public static let EVENT_PARAMS_OVERSIZED = "PARAMS_OVERSIZED"
    public static let EVENT_SIGNATURE_INVALID = "SIGNATURE_INVALID"
    public static let EVENT_SIGNATURE_EXPIRED = "SIGNATURE_EXPIRED"
    public static let EVENT_NONCE_REUSED = "NONCE_REUSED"
    public static let EVENT_TOKEN_INVALID = "TOKEN_INVALID"

    public struct AuditEntry {
        public let eventType: String
        public let method: String
        public let requestId: String
        public let detail: String
        public let timestamp: Int64
    }

    private var entries: [AuditEntry] = []
    private let maxEntries = 500
    private let lock = NSLock()

    private init() {}

    public func record(eventType: String, method: String, requestId: String, detail: String) {
        lock.lock()
        defer { lock.unlock() }

        let entry = AuditEntry(
            eventType: eventType,
            method: method,
            requestId: requestId,
            detail: detail,
            timestamp: Int64(Date().timeIntervalSince1970 * 1000)
        )
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    public func getEntries(limit: Int = 100) -> [AuditEntry] {
        lock.lock()
        defer { lock.unlock() }
        return Array(entries.suffix(limit))
    }

    public func getEntriesByType(_ eventType: String) -> [AuditEntry] {
        lock.lock()
        defer { lock.unlock() }
        return entries.filter { $0.eventType == eventType }
    }

    public func getSummary() -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }

        var summary: [String: Int] = [:]
        for entry in entries {
            summary[entry.eventType, default: 0] += 1
        }
        let summaryList = summary.map { ["eventType": $0.key, "count": $0.value] as [String: Any] }
        return ["totalEvents": entries.count, "summary": summaryList]
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
    }
}
