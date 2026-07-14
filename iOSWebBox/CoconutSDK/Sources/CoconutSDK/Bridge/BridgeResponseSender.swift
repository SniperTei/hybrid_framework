import Foundation
import WebKit

/// Abstracts JS execution so the response sender can be unit-tested with a mock.
public protocol JSExecutor: AnyObject {
    /// Execute the given JS script. Returns an error if evaluation failed.
    @discardableResult
    func evaluateJavaScript(_ script: String) async -> Error?
}

/// Production JSExecutor backed by a WKWebView. Holds the webview weakly.
public final class WebViewJSExecutor: JSExecutor {
    private weak var webView: WKWebView?

    public init(webView: WKWebView?) {
        self.webView = webView
    }

    @discardableResult
    public func evaluateJavaScript(_ script: String) async -> Error? {
        guard let webView = webView else { return nil }
        return await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(script) { _, error in
                continuation.resume(returning: error)
            }
        }
    }
}

/// Escapes a bridge response JSON string and invokes the H5 callback.
public final class BridgeResponseSender {

    private let tag = "BridgeResponseSender"
    private let executor: JSExecutor

    public init(executor: JSExecutor) {
        self.executor = executor
    }

    public func sendResponse(_ responseJson: String) async {
        let escaped = responseJson
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        let js = "window.__coconutIOSCallback('\(escaped)')"
        if let error = await executor.evaluateJavaScript(js) {
            Logger.shared.e(tag, "JS callback failed", error)
        }
    }
}
