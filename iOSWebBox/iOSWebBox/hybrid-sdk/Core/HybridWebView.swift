//
//  HybridWebView.swift
//  iOSWebBox
//
//  Enhanced WKWebView container
//

import UIKit
import WebKit

public class HybridWebView: WKWebView {
    private var config: HybridConfig?
    private var jsBridge: JSBridge?
    private var pluginContext: PluginContext?

    // Keep strong references to delegates
    private var navigationDelegateHolder: NavigationDelegateWrapper?
    private var uiDelegateHolder: UIDelegateWrapper?

    public var onNavigationError: ((Int, String?) -> Void)?

    public override init(frame: CGRect, configuration: WKWebViewConfiguration = WKWebViewConfiguration()) {
        super.init(frame: frame, configuration: configuration)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    public func initConfig(config: HybridConfig, viewController: UIViewController) {
        self.config = config

        // Initialize JSBridge
        self.jsBridge = JSBridge(webView: self)
        self.jsBridge?.setupMessageHandler()

        // Initialize plugin context
        self.pluginContext = PluginContext(
            applicationContext: UIApplication.shared,
            webView: self,
            viewController: viewController
        )

        // Configure WebView settings
        setupWebViewSettings(config)

        // Setup navigation delegate
        setupNavigationDelegate()

        // Setup UI delegate
        setupUIDelegate()

        // Inject JS SDK
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.jsBridge?.injectJSSDK()
        }
    }

    private func setupWebViewSettings(_ config: HybridConfig) {
        // WKWebView configuration is set during initialization
        // Additional setup can be done here if needed
    }

    private func setupNavigationDelegate() {
        let delegate = NavigationDelegateWrapper(webView: self)
        self.navigationDelegateHolder = delegate
        self.navigationDelegate = delegate
    }

    private func setupUIDelegate() {
        let delegate = UIDelegateWrapper()
        self.uiDelegateHolder = delegate
        self.uiDelegate = delegate
    }

    public func loadHybridURL(url: String) {
        guard let config = config, config.isUrlAllowed(url) else {
            print("URL not allowed: \(url)")
            return
        }

        if let urlObj = URL(string: url) {
            load(URLRequest(url: urlObj))
        }
    }

    public func getJSBridge() -> JSBridge? {
        jsBridge
    }

    public func getPluginManager() -> PluginManager? {
        jsBridge?.getPluginManager()
    }

    public func getPluginContext() -> PluginContext? {
        pluginContext
    }

    public func cleanup() {
        getPluginManager()?.unregisterAll()
        jsBridge = nil
        pluginContext = nil
        navigationDelegateHolder = nil
        uiDelegateHolder = nil
    }

    // Internal access for delegates
    func injectJSSDKIfNeeded() {
        jsBridge?.injectJSSDK()
    }

    func getConfig() -> HybridConfig? {
        config
    }
}

// MARK: - Navigation Delegate
class NavigationDelegateWrapper: NSObject, WKNavigationDelegate {
    private weak var webView: HybridWebView?

    init(webView: HybridWebView) {
        self.webView = webView
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url?.absoluteString {
            // Check URL whitelist
            if let hybridWebView = self.webView,
               let config = hybridWebView.getConfig(),
               !config.isUrlAllowed(url) {
                decisionHandler(.cancel)
                return
            }
        }

        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Re-inject JS SDK after page load
        self.webView?.injectJSSDKIfNeeded()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        self.webView?.onNavigationError?(nsError.code, nsError.localizedDescription)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        self.webView?.onNavigationError?(nsError.code, nsError.localizedDescription)
    }
}

// MARK: - UI Delegate
class UIDelegateWrapper: NSObject, WKUIDelegate {
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler()
        })

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(alert, animated: true)
        }
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completionHandler(false)
        })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler(true)
        })

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(alert, animated: true)
        }
    }
}
