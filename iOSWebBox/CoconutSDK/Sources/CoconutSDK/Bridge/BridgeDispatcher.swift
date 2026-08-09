import Foundation

/// Pure-logic bridge dispatcher. Does not depend on WKWebView — takes a JSON
/// request string and the current page URL, returns the JSON response string.
///
/// This isolation makes the dispatcher directly unit-testable without mocking
/// a WebView: feed in a request, assert the response.
public final class BridgeDispatcher {

    private let tag = "BridgeDispatcher"
    public let securityValidator = BridgeSecurityValidator()

    public init() {}

    /// Process a single bridge call end-to-end:
    /// parse → method format check → token → domain → rate limit →
    /// params size → component dispatch → response.
    @MainActor
    public func handleCall(_ jsonData: String, currentUrl: String) async -> String {
        // 1. Parse request
        guard let data = jsonData.data(using: .utf8),
              let request = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let method = request["method"] as? String,
              let id = request["id"] as? String else {
            return BridgeResponse.parseError(id: "").toJSON()
        }

        // Validate method format
        let methodPattern = "^[a-zA-Z][a-zA-Z0-9_]*\\.[a-zA-Z][a-zA-Z0-9_]*$"
        if method.range(of: methodPattern, options: .regularExpression) == nil {
            return BridgeResponse.invalidRequest(id: id, message: "Invalid method format: \(method)").toJSON()
        }

        Logger.shared.d(tag, "→ #\(id) \(method)")

        let params = request["params"] as? [String: Any]
        let bridgeToken = request["bridgeToken"] as? String ?? ""

        // 2. Bridge Token validation
        if !BridgeTokenManager.shared.validateToken(bridgeToken) {
            SecurityAuditLog.shared.record(
                eventType: SecurityAuditLog.EVENT_TOKEN_INVALID,
                method: method, requestId: id,
                detail: "Invalid or missing bridge token"
            )
            return BridgeResponse.error(id: id, code: ErrorCode.BRIDGE_TOKEN_INVALID, message: "Invalid bridge token").toJSON()
        }

        // 3. Domain whitelist check
        let domainResult = securityValidator.validateDomain(currentUrl)
        if !domainResult.isValid {
            SecurityAuditLog.shared.record(
                eventType: SecurityAuditLog.EVENT_DOMAIN_REJECTED,
                method: method, requestId: id, detail: domainResult.message
            )
            return BridgeResponse.error(id: id, code: ErrorCode.DOMAIN_NOT_ALLOWED, message: domainResult.message).toJSON()
        }

        // 5. Rate limit check
        let rateLimitResult = securityValidator.checkRateLimit(method)
        if !rateLimitResult.isValid {
            SecurityAuditLog.shared.record(
                eventType: SecurityAuditLog.EVENT_RATE_LIMITED,
                method: method, requestId: id, detail: rateLimitResult.message
            )
            return BridgeResponse.error(id: id, code: ErrorCode.RATE_LIMIT_EXCEEDED, message: rateLimitResult.message).toJSON()
        }

        // 6. Params size check
        let paramsSizeResult = securityValidator.validateParamsSize(jsonData)
        if !paramsSizeResult.isValid {
            SecurityAuditLog.shared.record(
                eventType: SecurityAuditLog.EVENT_PARAMS_OVERSIZED,
                method: method, requestId: id, detail: paramsSizeResult.message
            )
            return BridgeResponse.error(id: id, code: ErrorCode.PARAM_VALIDATION_FAILED, message: paramsSizeResult.message).toJSON()
        }

        // 7. Dispatch to component with performance tracking
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            let parts = method.components(separatedBy: ".")
            let componentName = parts[0]
            let functionName = parts[1]

            guard let component = ComponentManager.shared.getComponent(name: componentName) else {
                throw ComponentNotFoundException("Component not found: \(componentName)")
            }
            guard component.isInitialized else {
                throw ComponentNotInitializedException("Component not initialized: \(componentName)")
            }

            let result = try await component.handle(function: functionName, params: params)

            let durationMs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            BridgePerformance.shared.record(method: method, durationMs: durationMs, success: true)

            Logger.shared.d(tag, "✓ #\(id) \(method)")
            return BridgeResponse.success(id: id, result: result).toJSON()

        } catch let e as ComponentNotFoundException {
            let durationMs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            BridgePerformance.shared.record(method: method, durationMs: durationMs, success: false)
            return BridgeResponse.error(id: id, code: ErrorCode.UNKNOWN_COMPONENT, message: e.message).toJSON()

        } catch let e as ComponentNotInitializedException {
            let durationMs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            BridgePerformance.shared.record(method: method, durationMs: durationMs, success: false)
            return BridgeResponse.error(id: id, code: ErrorCode.COMPONENT_NOT_INITIALIZED, message: e.message).toJSON()

        } catch let e as ComponentException {
            let durationMs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            BridgePerformance.shared.record(method: method, durationMs: durationMs, success: false)
            return BridgeResponse.error(id: id, code: e.code, message: e.message).toJSON()

        } catch {
            let durationMs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            BridgePerformance.shared.record(method: method, durationMs: durationMs, success: false)
            return BridgeResponse.internalError(id: id, message: error.localizedDescription).toJSON()
        }
    }
}
