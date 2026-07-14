import Foundation
import WebKit
import CoconutSDK

public class StackComponent: BaseComponent {
    override public init() { super.init() }

    override public var name: String { "stack" }
    override public var version: String { "1.0.0" }
    override public var pluginDescription: String { "WebView navigation stack component" }

    private var componentContext: ComponentContext?

    override public func onInit(context: ComponentContext) async {
        componentContext = context
    }

    override public func handle(function: String, params: [String: Any]?) async throws -> [String: Any] {
        switch function {
        case "push": return try await push(params)
        case "pop": return await pop()
        case "replace": return try await replace(params)
        case "backTo": return await backTo(params)
        case "getSize": return getSize()
        case "getStack": return getStack()
        case "canGoBack": return canGoBack()
        default: try functionNotSupportedError(function)
        }
    }

    @MainActor
    private func push(_ params: [String: Any]?) throws -> [String: Any] {
        let url = getParam(params, "url")
        if url.isEmpty { try error("200007", "Parameter 'url' is required") }

        guard let webView = componentContext?.currentWebView,
              let requestUrl = URL(string: url) else {
            return success(["success": false])
        }

        webView.load(URLRequest(url: requestUrl))
        return success(["success": true, "url": url])
    }

    @MainActor
    private func pop() -> [String: Any] {
        guard let webView = componentContext?.currentWebView else {
            return success(["success": false])
        }

        if webView.canGoBack {
            webView.goBack()
            return success(["success": true])
        }
        return success(["success": false])
    }

    @MainActor
    private func replace(_ params: [String: Any]?) throws -> [String: Any] {
        let url = getParam(params, "url")
        if url.isEmpty { try error("200007", "Parameter 'url' is required") }

        guard let webView = componentContext?.currentWebView,
              let requestUrl = URL(string: url) else {
            return success(["success": false])
        }

        webView.load(URLRequest(url: requestUrl))
        return success(["success": true, "url": url])
    }

    @MainActor
    private func backTo(_ params: [String: Any]?) -> [String: Any] {
        let index = getIntParam(params, "index", -1)
        let url = getParam(params, "url")

        guard let webView = componentContext?.currentWebView else {
            return success(["success": false])
        }

        let list = webView.backForwardList

        if index >= 0 && index < list.backList.count {
            let item = list.backList[index]
            webView.go(to: item)
            return success(["success": true, "url": item.url.absoluteString])
        }

        if !url.isEmpty {
            for item in list.backList.reversed() {
                if item.url.absoluteString == url || item.url.absoluteString.hasPrefix(url) {
                    webView.go(to: item)
                    return success(["success": true, "url": item.url.absoluteString])
                }
            }
        }

        return success(["success": false])
    }

    private func getSize() -> [String: Any] {
        guard let webView = componentContext?.currentWebView else {
            return success(["size": 0])
        }
        let list = webView.backForwardList
        return success(["size": list.backList.count + 1])
    }

    private func getStack() -> [String: Any] {
        guard let webView = componentContext?.currentWebView else {
            return success(["stack": [[String: Any]]()])
        }

        let list = webView.backForwardList
        var stack: [[String: Any]] = []

        for (index, item) in list.backList.enumerated() {
            stack.append([
                "index": index,
                "url": item.url.absoluteString,
                "title": item.title ?? ""
            ])
        }

        stack.append([
            "index": list.backList.count,
            "url": list.currentItem?.url.absoluteString ?? "",
            "title": list.currentItem?.title ?? ""
        ])

        return success(["stack": stack, "size": stack.count])
    }

    private func canGoBack() -> [String: Any] {
        let canBack = componentContext?.currentWebView?.canGoBack ?? false
        return success(["canGoBack": canBack])
    }

    override public func onCleanup() async {
        componentContext = nil
    }
}
