import Foundation
importWebKit

/// JSBridge核心类
/// 负责H5与Native的双向通信
public class JSBridge: NSObject {
    private weak var webView: WKWebView?
    private let pluginManager: PluginManager

    public init(webView: WKWebView) {
        self.webView = webView
        self.pluginManager = PluginManager(jsBridge: self)
        super.init()
    }

    /// 初始化JSBridge
    public func init(viewController: UIViewController) {
        pluginManager.init(viewController: viewController)
        injectJSSDK()
    }

    /// 获取插件管理器
    public func getPluginManager() -> PluginManager {
        return pluginManager
    }

    /// 注入JavaScript SDK
    private func injectJSSDK() {
        guard let jsPath = Bundle.module.path(forResource: "hybrid-sdk", ofType: "js"),
              let jsCode = try? String(contentsOfFile: jsPath) else {
            print("Failed to load hybrid-sdk.js")
            return
        }

        let userScript = WKUserScript(source: jsCode, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        webView?.configuration.userContentController.addUserScript(userScript)

        // 添加ScriptMessageHandler
        webView?.configuration.userContentController.add(self, name: "AndroidWebBoxNative")
    }

    /// Native回调JS
    public func callJs(
        callbackId: String,
        success: Bool?,
        data: Any?,
        progress: Int?,
        error: (String, String)?
    ) {
        var dataString = "null"
        if let data = data {
            if let dataDict = data as? [String: Any] {
                if let jsonData = try? JSONSerialization.data(withJSONObject: dataDict, options: []) {
                    dataString = String(data: jsonData, encoding: .utf8) ?? "null"
                }
            } else if let dataStr = data as? String {
                dataString = "'\(dataStr.replacingOccurrences(of: "'", with: "\\'"))'"
            } else if let dataNum = data as? NSNumber {
                dataString = dataNum.stringValue
            } else if let dataBool = data as? Bool {
                dataString = dataBool ? "true" : "false"
            }
        }

        let successStr: String
        if let success = success {
            successStr = success ? "true" : "false"
        } else {
            successStr = "null"
        }

        let progressStr = progress.map { String($0) } ?? "null"

        let errorStr: String
        if let error = error {
            errorStr = "{ code: '\(error.0)', message: '\(error.1.replacingOccurrences(of: "'", with: "\\'"))' }"
        } else {
            errorStr = "null"
        }

        let jsCode = """
            if (window.AndroidWebBox) {
                AndroidWebBox.onNativeCallback('\(callbackId)', \(successStr), \(dataString), \(progressStr), \(errorStr));
            }
        """

        DispatchQueue.main.async {
            self.webView?.evaluateJavaScript(jsCode) { _, error in
                if let error = error {
                    print("JS callback error: \(error)")
                }
            }
        }
    }

    /// Native发送事件到JS
    public func emitEvent(eventName: String, data: Any?) {
        var dataString = "null"
        if let data = data {
            if let dataDict = data as? [String: Any] {
                if let jsonData = try? JSONSerialization.data(withJSONObject: dataDict, options: []) {
                    dataString = String(data: jsonData, encoding: .utf8) ?? "null"
                }
            } else if let dataStr = data as? String {
                dataString = "'\(dataStr.replacingOccurrences(of: "'", with: "\\'"))'"
            } else if let dataNum = data as? NSNumber {
                dataString = dataNum.stringValue
            } else if let dataBool = data as? Bool {
                dataString = dataBool ? "true" : "false"
            }
        }

        let jsCode = """
            if (window.AndroidWebBox) {
                AndroidWebBox.onNativeEvent('\(eventName)', \(dataString));
            }
        """

        DispatchQueue.main.async {
            self.webView?.evaluateJavaScript(jsCode) { _, error in
                if let error = error {
                    print("JS event error: \(error)")
                }
            }
        }
    }
}

// MARK: - WKScriptMessageHandler
extension JSBridge: WKScriptMessageHandler {
    public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "AndroidWebBoxNative",
              let messageBody = message.body as? String,
              let jsonData = messageBody.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let callbackId = json["callbackId"] as? String,
              let plugin = json["plugin"] as? String,
              let action = json["action"] as? String else {
            return
        }

        let params = json["params"] as? [String: Any] ?? [:]

        pluginManager.exec(pluginName: plugin, action: action, params: params, callbackId: callbackId)
    }
}
