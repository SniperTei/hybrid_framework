import Foundation
import WebKit

public class CoconutBridge: NSObject, WKScriptMessageHandler {

    private let tag = "CoconutBridge"

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
        guard let data = jsonData.data(using: .utf8),
              let request = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let method = request["method"] as? String,
              let id = request["id"] as? String else {
            return errorResponse(id: "", code: -32700, message: "Parse error")
        }

        let methodPattern = "^[a-zA-Z][a-zA-Z0-9_]*\\.[a-zA-Z][a-zA-Z0-9_]*$"
        if method.range(of: methodPattern, options: .regularExpression) == nil {
            return errorResponse(id: id, code: -32600, message: "Invalid method format: \(method)")
        }

        Logger.shared.d(tag, "→ #\(id) \(method)")

        let parts = method.components(separatedBy: ".")
        let componentName = parts[0]
        let functionName = parts[1]
        let params = request["params"] as? [String: Any]

        guard let component = ComponentManager.shared.getComponent(name: componentName) else {
            return errorResponse(id: id, code: 900001, message: "Component not found: \(componentName)")
        }

        guard component.isInitialized else {
            return errorResponse(id: id, code: 900008, message: "Component not initialized: \(componentName)")
        }

        let result = await component.handle(function: functionName, params: params)

        Logger.shared.d(tag, "✓ #\(id) \(method)")
        return successResponse(id: id, result: result)
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

    private func successResponse(id: String, result: [String: Any]) -> String {
        return jsonString(from: [
            "jsonrpc": "2.0",
            "result": result,
            "error": NSNull(),
            "id": id
        ])
    }

    private func errorResponse(id: String, code: Int, message: String) -> String {
        return jsonString(from: [
            "jsonrpc": "2.0",
            "result": NSNull(),
            "error": ["code": code, "message": message],
            "id": id
        ])
    }

    private func jsonString(from dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else {
            return "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32603,\"message\":\"JSON error\"},\"id\":\"\"}"
        }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
