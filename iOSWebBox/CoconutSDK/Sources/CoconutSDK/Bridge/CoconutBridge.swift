import Foundation
import WebKit

/// Public bridge entry point. Implements `WKScriptMessageHandler` to receive
/// messages from H5, delegates dispatch to `BridgeDispatcher` (pure logic) and
/// response delivery to `BridgeResponseSender` (JS execution).
///
/// The public surface (`init()`, `securityValidator`) is preserved so that
/// `CoconutWebViewController` requires no changes.
public class CoconutBridge: NSObject, WKScriptMessageHandler {

    private let tag = "CoconutBridge"
    private let dispatcher = BridgeDispatcher()

    public override init() {
        super.init()
    }

    /// Pass-through to the dispatcher's validator so the host app can configure
    /// domain whitelist / rate limits / params size exactly as before.
    public var securityValidator: BridgeSecurityValidator {
        dispatcher.securityValidator
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
            let responseJson = await self.dispatcher.handleCall(requestJson, currentUrl: currentUrl)
            let sender = BridgeResponseSender(executor: WebViewJSExecutor(webView: webView))
            await sender.sendResponse(responseJson)
        }
    }
}
