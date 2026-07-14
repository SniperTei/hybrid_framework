import Foundation
import CoconutSDK

public class SecurityComponent: BaseComponent {
    override public init() { super.init() }

    override public var name: String { "security" }
    override public var version: String { "2.0.0" }
    override public var pluginDescription: String { "Security audit and configuration component" }

    private var componentContext: ComponentContext?

    override public func onInit(context: ComponentContext) async {
        componentContext = context
    }

    override public func handle(function: String, params: [String: Any]?) async throws -> [String: Any] {
        switch function {
        case "getAuditLog": return getAuditLog(params)
        case "getAuditSummary": return getAuditSummary()
        case "getSecurityConfig": return getSecurityConfig()
        case "clearAuditLog": return clearAuditLog()
        default: try functionNotSupportedError(function)
        }
    }

    private func getAuditLog(_ params: [String: Any]?) -> [String: Any] {
        let type = getParam(params, "type")
        let limit = getIntParam(params, "limit", 100)

        let entries: [SecurityAuditLog.AuditEntry]
        if !type.isEmpty {
            entries = SecurityAuditLog.shared.getEntriesByType(type)
        } else {
            entries = SecurityAuditLog.shared.getEntries(limit: limit)
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
        return SecurityAuditLog.shared.getSummary()
    }

    private func getSecurityConfig() -> [String: Any] {
        return success([
            "bridgeTokenEnabled": BridgeTokenManager.shared.enabled,
            "requestSigningEnabled": RequestSignatureValidator.shared.enabled,
            "signingTimestampToleranceMs": RequestSignatureValidator.shared.timestampToleranceMs
        ])
    }

    private func clearAuditLog() -> [String: Any] {
        SecurityAuditLog.shared.clear()
        return success(["success": true])
    }

    override public func onCleanup() async {
        componentContext = nil
    }
}
