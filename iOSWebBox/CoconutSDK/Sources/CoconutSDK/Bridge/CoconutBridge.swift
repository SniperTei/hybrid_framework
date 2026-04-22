import Foundation
import WebKit

public class CoconutBridge: NSObject, WKScriptMessageHandler {

    private let tag = "CoconutBridge"
    let securityValidator = BridgeSecurityValidator()

    public override init() {
        super.init()
    }

    public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "CoconutBridge" else { return }

        var requestJson: String?
        if let body = message.body as? String {
            requestJson = body
        } else if let body = message.body as? [String: Any] {
            if let data = try? JSONSerialization.data(withJSONObject: body),
               let str = String(data: data, encoding: .utf8) {
                requestJson = str
            }
        }

        guard let requestJson = requestJson else {
            Logger.shared.e(tag, "Invalid bridge message: \(message.body)")
            return
        }

        Logger.shared.d(tag, "Received: \(requestJson)")

        let webView = message.webView
        let currentUrl = webView?.url?.absoluteString ?? ""

        Task { @MainActor in
            let responseJson = await handleCall(requestJson, currentUrl: currentUrl)
            self.sendResponse(webView: webView, responseJson: responseJson)
        }
    }

    private func handleCall(_ jsonData: String, currentUrl: String) async -> String {
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
        let timestamp = request["timestamp"] as? Int64 ?? 0
        let nonce = request["nonce"] as? String ?? ""
        let sign = request["sign"] as? String ?? ""

        // 2. Bridge Token validation
        if !BridgeTokenManager.shared.validateToken(bridgeToken) {
            SecurityAuditLog.shared.record(
                eventType: SecurityAuditLog.EVENT_TOKEN_INVALID,
                method: method, requestId: id,
                detail: "Invalid or missing bridge token"
            )
            return BridgeResponse.error(id: id, code: ErrorCode.BRIDGE_TOKEN_INVALID, message: "Invalid bridge token").toJSON()
        }

        // 3. Request signature validation
        let paramsJson = params != nil ? (try? String(data: JSONSerialization.data(withJSONObject: params!), encoding: .utf8)) ?? "" : ""
        let signResult = RequestSignatureValidator.shared.validate(
            method: method, id: id, timestamp: timestamp,
            nonce: nonce, paramsJson: paramsJson, sign: sign
        )
        switch signResult {
        case .invalid(let errorCode, let message):
            let eventType: String
            switch errorCode {
            case ErrorCode.SIGNATURE_INVALID: eventType = SecurityAuditLog.EVENT_SIGNATURE_INVALID
            case ErrorCode.SIGNATURE_EXPIRED: eventType = SecurityAuditLog.EVENT_SIGNATURE_EXPIRED
            case ErrorCode.NONCE_REUSED: eventType = SecurityAuditLog.EVENT_NONCE_REUSED
            default: eventType = SecurityAuditLog.EVENT_SIGNATURE_INVALID
            }
            SecurityAuditLog.shared.record(eventType: eventType, method: method, requestId: id, detail: message)
            return BridgeResponse.error(id: id, code: errorCode, message: message).toJSON()
        case .valid:
            break
        }

        // 4. Domain whitelist check
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
        var bridgeSuccess = true

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

    private func sendResponse(webView: WKWebView?, responseJson: String) {
        guard let webView = webView else { return }
        let escaped = responseJson
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        let js = "window.__coconutIOSCallback('\(escaped)')"
        webView.evaluateJavaScript(js) { _, error in
            if let error = error {
                Logger.shared.e(self.tag, "JS callback failed", error)
            }
        }
    }

    func extractMethodFromJson(_ jsonData: String) -> String {
        guard let range = jsonData.range(of: "\"method\":\"") else { return "unknown" }
        let rest = jsonData[range.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return "unknown" }
        return String(rest[..<end])
    }

    func extractIdFromJson(_ jsonData: String) -> String {
        guard let range = jsonData.range(of: "\"id\":\"") else { return "" }
        let rest = jsonData[range.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return "" }
        return String(rest[..<end])
    }
}
