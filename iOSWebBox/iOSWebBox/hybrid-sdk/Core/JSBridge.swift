//
//  JSBridge.swift
//  iOSWebBox
//
//  JavaScript-Native bridge
//

import Foundation
import WebKit

public class JSBridge: NSObject {
    private weak var webView: WKWebView?
    private var pluginManager: PluginManager?

    public init(webView: WKWebView) {
        self.webView = webView
        super.init()
        self.pluginManager = PluginManager(jsBridge: self)
    }

    public func getPluginManager() -> PluginManager {
        pluginManager!
    }

    public func setupMessageHandler() {
        webView?.configuration.userContentController.add(self, name: "AndroidWebBoxNative")
    }

    public func injectJSSDK() {
        guard let jsSDKPath = Bundle.main.path(forResource: "hybrid-sdk", ofType: "js", inDirectory: "resources/js"),
              let jsSDK = try? String(contentsOfFile: jsSDKPath) else {
            print("Failed to load hybrid-sdk.js")
            return
        }

        let jsCode = """
        (function() {
            try {
                \(jsSDK)
            } catch(e) {
                console.error('Failed to inject JS SDK:', e);
            }
        })();
        """

        webView?.evaluateJavaScript(jsCode) { _, error in
            if let error = error {
                print("Failed to inject JS SDK: \(error)")
            } else {
                print("JS SDK injected successfully")
            }
        }
    }

    public func callJs(callbackId: String, success: Bool?, data: Any?, progress: Int?, error: (String, String)?) {
        let dataStr: String
        if let data = data {
            if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: []),
               let jsonStr = String(data: jsonData, encoding: .utf8) {
                dataStr = jsonStr
            } else if let str = data as? String {
                dataStr = "'\(str.replacingOccurrences(of: "'", with: "\\'"))'"
            } else if let num = data as? NSNumber {
                dataStr = num.stringValue
            } else {
                dataStr = "{}"
            }
        } else {
            dataStr = "null"
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
            let escapedCode = error.0.replacingOccurrences(of: "'", with: "\\'")
            let escapedMsg = error.1.replacingOccurrences(of: "'", with: "\\'")
            errorStr = "{code: '\(escapedCode)', message: '\(escapedMsg)'}"
        } else {
            errorStr = "null"
        }

        let jsCode = """
        if (window.AndroidWebBox && window.AndroidWebBox.onNativeCallback) {
            AndroidWebBox.onNativeCallback('\(callbackId)', \(successStr), \(dataStr), \(progressStr), \(errorStr));
        }
        """

        DispatchQueue.main.async {
            self.webView?.evaluateJavaScript(jsCode) { _, error in
                if let error = error {
                    print("Failed to call JS callback: \(error)")
                }
            }
        }
    }

    public func emitEvent(eventName: String, data: Any?) {
        let dataStr: String
        if let data = data {
            if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: []),
               let jsonStr = String(data: jsonData, encoding: .utf8) {
                dataStr = jsonStr
            } else {
                dataStr = "{}"
            }
        } else {
            dataStr = "null"
        }

        let jsCode = """
        if (window.AndroidWebBox && window.AndroidWebBox.onNativeEvent) {
            AndroidWebBox.onNativeEvent('\(eventName)', \(dataStr));
        }
        """

        DispatchQueue.main.async {
            self.webView?.evaluateJavaScript(jsCode) { _, error in
                if let error = error {
                    print("Failed to emit event: \(error)")
                }
            }
        }
    }
}

extension JSBridge: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "AndroidWebBoxNative",
              let messageBody = message.body as? String,
              let jsonData = messageBody.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return
        }

        let callbackId = json["callbackId"] as? String ?? ""
        let plugin = json["plugin"] as? String ?? ""
        let action = json["action"] as? String ?? ""
        let params = json["params"] as? [String: Any] ?? [:]

        pluginManager?.exec(pluginName: plugin, action: action, params: params, callbackId: callbackId)
    }
}
