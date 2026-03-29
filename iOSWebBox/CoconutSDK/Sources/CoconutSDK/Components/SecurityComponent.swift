import Foundation

public class SecurityComponent: BaseComponent {

    override public var name: String { "security" }
    override public var version: String { "1.0.0" }
    override public var pluginDescription: String { "Security audit and configuration component" }

    private var componentContext: ComponentContext?
    private var auditLog: [AuditEntry] = []

    struct AuditEntry {
        let eventType: String
        let method: String
        let requestId: String
        let detail: String
        let timestamp: Int64
    }

    override public func onInit(context: ComponentContext) async {
        componentContext = context
    }

    override public func handle(function: String, params: [String: Any]?) async -> [String: Any] {
        switch function {
        case "getAuditLog": return getAuditLog(params)
        case "getAuditSummary": return getAuditSummary()
        case "getSecurityConfig": return getSecurityConfig()
        case "clearAuditLog": return clearAuditLog()
        default: return functionNotSupportedError(function)
        }
    }

    private func getAuditLog(_ params: [String: Any]?) -> [String: Any] {
        let type = getParam(params, "type")
        let limit = getIntParam(params, "limit", 100)

        let entries: [AuditEntry]
        if !type.isEmpty {
            entries = auditLog.filter { $0.eventType == type }
        } else {
            entries = Array(auditLog.suffix(limit))
        }

        let records = entries.map { entry -> [String: Any] in
            return [
                "eventType": entry.eventType,
                "method": entry.method,
                "requestId": entry.requestId,
                "detail": entry.detail,
                "timestamp": entry.timestamp
            ]
        }

        return success(["count": records.count, "entries": records])
    }

    private func getAuditSummary() -> [String: Any] {
        var summary: [String: Int] = [:]
        for entry in auditLog {
            summary[entry.eventType, default: 0] += 1
        }
        let summaryList = summary.map { (type, count) -> [String: Any] in
            return ["eventType": type, "count": count]
        }
        return success(["totalEvents": auditLog.count, "summary": summaryList])
    }

    private func getSecurityConfig() -> [String: Any] {
        return success([
            "bridgeTokenEnabled": false,
            "requestSigningEnabled": false,
            "signingTimestampToleranceMs": 300000
        ])
    }

    private func clearAuditLog() -> [String: Any] {
        auditLog.removeAll()
        return success(["success": true])
    }

    override public func onCleanup() async {
        componentContext = nil
        auditLog.removeAll()
    }
}
