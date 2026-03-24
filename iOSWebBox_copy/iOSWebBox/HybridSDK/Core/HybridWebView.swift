import UIKit
import WebKit

/// 增强的WKWebView容器
public class HybridWebView: WKWebView {
    private var config: HybridConfig?
    private var jsBridge: JSBridge?
    private var viewController: UIViewController?

    // 自定义拦截器
    private var urlInterceptor: ((String) -> Bool)?
    private var errorListener: ((Error, String?) -> Void)?

    // MARK: - Initialization

    public init(frame: CGRect) {
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true

        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences

        super.init(frame: frame, configuration: configuration)

        setupNavigationDelegate()
        setupUIDelegate()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public Methods

    /// 初始化
    public func initConfig(config: HybridConfig, viewController: UIViewController) {
        self.config = config
        self.viewController = viewController

        // 初始化JSBridge
        self.jsBridge = JSBridge(webView: self)
        jsBridge?.init(viewController: viewController)

        // 配置WebView设置
        setupWebViewSettings(config)
    }

    /// 加载URL（带白名单检查）
    public func loadHybridURL(url: String) {
        guard let config = config else { return }

        if config.isUrlAllowed(url) {
            if let urlObj = URL(string: url) {
                let request = URLRequest(url: urlObj)
                load(request)
            }
        } else {
            print("URL not in whitelist: \(url)")
        }
    }

    /// 获取JSBridge实例
    public func getJSBridge() -> JSBridge? {
        return jsBridge
    }

    /// 获取插件管理器
    public func getPluginManager() -> PluginManager? {
        return jsBridge?.getPluginManager()
    }

    /// 设置URL拦截器
    public func setUrlInterceptor(_ interceptor: @escaping (String) -> Bool) {
        self.urlInterceptor = interceptor
    }

    /// 设置错误监听器
    public func setErrorListener(_ listener: @escaping (Error, String?) -> Void) {
        self.errorListener = listener
    }

    // MARK: - Private Methods

    /// 配置WebView设置
    private func setupWebViewSettings(_ config: HybridConfig) {
        // JavaScript已通过WKPreferences启用
        // 在iOS中,DOM Storage和Database默认启用

        // 配置数据检测
        if #available(iOS 14.0, *) {
            // iOS 14+ 可以配置默认行为
        }

        // User-Agent设置
        if let userAgent = config.userAgent {
            evaluateJavaScript("navigator.userAgent") { [weak self] result, error in
                if var ua = result as? String {
                    ua = userAgent + " " + ua
                    self?.customUserAgent = ua
                }
            }
        }
    }

    /// 设置NavigationDelegate
    private func setupNavigationDelegate() {
        navigationDelegate = self
    }

    /// 设置UIDelegate
    private func setupUIDelegate() {
        uiDelegate = self
    }

    /// 清理资源
    public func cleanup() {
        getPluginManager()?.unregisterAll()
        configuration.userContentController.removeAllScriptMessageHandlers()
    }

    deinit {
        cleanup()
    }
}

// MARK: - WKNavigationDelegate
extension HybridWebView: WKNavigationDelegate {
    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url?.absoluteString else {
            decisionHandler(.cancel)
            return
        }

        // 检查URL白名单
        if let config = config, !config.isUrlAllowed(url) {
            decisionHandler(.cancel)
            return
        }

        // 自定义URL拦截
        if let interceptor = urlInterceptor, interceptor(url) {
            decisionHandler(.cancel)
            return
        }

        // 处理特殊协议
        if url.hasPrefix("tel:") {
            if let telUrl = URL(string: url) {
                UIApplication.shared.open(telUrl)
            }
            decisionHandler(.cancel)
            return
        }

        if url.hasPrefix("mailto:") {
            if let mailUrl = URL(string: url) {
                UIApplication.shared.open(mailUrl)
            }
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // 页面加载完成后重新注入JS SDK
        jsBridge?.init(viewController: viewController!)
    }

    public func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        errorListener?(error, nil)
    }

    public func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        errorListener?(error, nil)
    }
}

// MARK: - WKUIDelegate
extension HybridWebView: WKUIDelegate {
    public func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let alert = UIAlertController(
            title: nil,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler()
        })

        viewController?.present(alert, animated: true)
    }

    public func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let alert = UIAlertController(
            title: nil,
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler(true)
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completionHandler(false)
        })

        viewController?.present(alert, animated: true)
    }

    public func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        let alert = UIAlertController(
            title: nil,
            message: prompt,
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.text = defaultText
        }

        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler(alert.textFields?.first?.text)
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completionHandler(nil)
        })

        viewController?.present(alert, animated: true)
    }

    public func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            if let url = navigationAction.request.url {
                UIApplication.shared.open(url)
            }
        }
        return nil
    }
}
