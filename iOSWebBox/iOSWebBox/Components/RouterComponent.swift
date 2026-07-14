import Foundation
import UIKit
import WebKit
import CoconutSDK

public class RouterComponent: BaseComponent {
    override public init() { super.init() }

    override public var name: String { "router" }
    override public var version: String { "1.0.0" }
    override public var pluginDescription: String { "Navigation and routing component" }

    private var componentContext: ComponentContext?

    override public func onInit(context: ComponentContext) async {
        componentContext = context
    }

    override public func handle(function: String, params: [String: Any]?) async throws -> [String: Any] {
        switch function {
        case "open": return try await open(params)
        case "back": return await back()
        case "getScheme": return getScheme()
        default: try functionNotSupportedError(function)
        }
    }

    @MainActor
    private func open(_ params: [String: Any]?) throws -> [String: Any] {
        let url = getParam(params, "url")
        if url.isEmpty { try error("200007", "Parameter 'url' is required") }

        if url.hasPrefix("coconut://native/") {
            // Native route - emit JS event
            let path = String(url.dropFirst("coconut://native/".count))
            let webView = componentContext?.currentWebView
            let js = "window.dispatchEvent && window.dispatchEvent(new CustomEvent('coconutNativeRoute', {detail: {path: '\(path)'}}))"
            webView?.evaluateJavaScript(js)
            return success(["type": "native", "path": path])

        } else if url.hasPrefix("coconut://h5/") {
            // H5 route - load in WebView
            let path = String(url.dropFirst("coconut://h5/".count))
            let webView = componentContext?.currentWebView
            webView?.load(URLRequest(url: URL(string: path) ?? URL(string: "about:blank")!))
            return success(["type": "h5", "path": path])

        } else if url.hasPrefix("https://") || url.hasPrefix("http://") {
            // HTTP URL - load in WebView
            let webView = componentContext?.currentWebView
            if let requestUrl = URL(string: url) {
                webView?.load(URLRequest(url: requestUrl))
                return success(["type": "web", "url": url])
            }
            return success(["type": "error", "message": "Invalid URL"])

        } else {
            return success(["type": "unsupported", "url": url])
        }
    }

    @MainActor
    private func back() -> [String: Any] {
        let webView = componentContext?.currentWebView
        if let webView = webView, webView.canGoBack {
            webView.goBack()
            return success(["success": true, "canGoBack": webView.canGoBack])
        }
        return success(["success": false, "canGoBack": false])
    }

    private func getScheme() -> [String: Any] {
        return success([
            "scheme": "coconut",
            "nativePrefix": "coconut://native/",
            "h5Prefix": "coconut://h5/"
        ])
    }

    override public func onCleanup() async {
        componentContext = nil
    }
}
