import Foundation
import UIKit
import WebKit

public class CoconutWebViewController: UIViewController, ComponentHost {

    private let tag = "CoconutWebVC"
    public private(set) var webView: WKWebView?
    private var bridge: CoconutBridge!
    private var progressView: UIProgressView!
    private var currentUrl: String?
    private var containerView: UIView!
    private var errorPageView: UIView?
    private var progressObservation: NSKeyValueObservation?

    public var enableDebug: Bool = false

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupWebView()
        setupBridge()
        applySecurityConfig()

        ComponentManager.shared.setHost(self)

        if enableDebug {
            CoconutSDK.configure { config in
                config.debugMode = true
            }
        }
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = .white

        containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        progressView = UIProgressView(progressViewStyle: .default)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progress = 0
        progressView.isHidden = true
        view.addSubview(progressView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2)
        ])
    }

    // MARK: - WebView Setup

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        // Secure WebView settings
        if #available(iOS 14.0, *) {
            config.defaultWebpagePreferences.allowsContentJavaScript = true
        }

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.translatesAutoresizingMaskIntoConstraints = false
        wv.navigationDelegate = self
        wv.isOpaque = false
        wv.backgroundColor = .white
        webView = wv

        // KeyPath-based observation: auto-invalidates on deinit, no manual removeObserver needed.
        progressObservation = wv.observe(\.estimatedProgress, options: [.new]) { [weak self] _, _ in
            guard let self else { return }
            let progress = Float(wv.estimatedProgress)
            self.progressView.progress = progress
            self.progressView.isHidden = progress >= 1.0
        }

        containerView.addSubview(wv)
        NSLayoutConstraint.activate([
            wv.topAnchor.constraint(equalTo: containerView.topAnchor),
            wv.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }

    // MARK: - Bridge Setup

    private func setupBridge() {
        bridge = CoconutBridge()
        if let webView = webView {
            webView.configuration.userContentController.add(bridge, name: "CoconutBridge")
        }

        // Wire EventEmitter → WebView. The host owns the WebView lifecycle, so
        // we hand it a fresh executor each setupBridge pass.
        ComponentManager.shared.sharedContext.eventEmitter.jsExecutor = WebViewJSExecutor(webView: webView)

        Logger.shared.d(tag, "Bridge setup complete")
    }

    // MARK: - Security Config

    private func applySecurityConfig() {
        let config = CoconutConfig.shared

        // Apply domain whitelist to bridge security validator
        if !config.allowedDomains.isEmpty {
            bridge.securityValidator.setAllowedDomains(config.allowedDomains)
        }
        bridge.securityValidator.maxParamsSize = config.maxBridgeParamsSize
        bridge.securityValidator.rateLimitPerMethod = config.rateLimitPerMethod
        bridge.securityValidator.rateLimitWindowMs = config.rateLimitWindowMs

        Logger.shared.d(tag, "Security config applied: token=\(config.enableBridgeToken)")
    }

    // MARK: - Bridge JS Injection

    private func injectBridgeJavaScript() {
        guard let webView = webView else { return }
        let token = BridgeTokenManager.shared.getToken()

        let js = Self.bridgeBootstrapJS(token: token)
        webView.evaluateJavaScript(js)
        Logger.shared.d(tag, "Bridge security config injected (token: \(token.prefix(8))...)")
    }

    /// Builds the security-config bootstrap JS injected into the page after navigation finishes.
    /// Extracted to a static method so the script shape is unit-testable without a WebView.
    private static func bridgeBootstrapJS(token: String) -> String {
        return """
        (function() {
            if (window.__coconutInitialized) return;
            window.__coconutConfig = {
                token: '\(token)'
            };
            if (window.Coconut && window.Coconut._loadSecurityConfig) {
                window.Coconut._loadSecurityConfig();
            }
            window.__coconutInitialized = true;
            console.log('Coconut SDK security config injected (iOS)');
        })();
        """
    }

    // MARK: - Public Methods

    public func loadUrl(_ urlString: String) {
        currentUrl = urlString
        hideErrorPage()
        guard let url = URL(string: urlString) else {
            Logger.shared.e(tag, "Invalid URL: \(urlString)")
            return
        }
        Logger.shared.d(tag, "Loading URL: \(urlString)")
        webView?.load(URLRequest(url: url))
    }

    public func evaluateJavascript(_ script: String) {
        webView?.evaluateJavaScript(script)
    }

    public func goBack() {
        guard let webView = webView, webView.canGoBack else { return }
        webView.goBack()
    }

    // MARK: - Error Page

    private func showErrorPage() {
        guard errorPageView == nil else { return }

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = "页面加载失败\n请检查网络连接"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .gray
        label.font = .systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        let retryButton = UIButton(type: .system)
        retryButton.setTitle("重试", for: .normal)
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.addTarget(self, action: #selector(retryLoad), for: .touchUpInside)
        container.addSubview(retryButton)
        NSLayoutConstraint.activate([
            retryButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            retryButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 16)
        ])

        containerView.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: containerView.topAnchor),
            container.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        errorPageView = container
    }

    private func hideErrorPage() {
        errorPageView?.removeFromSuperview()
        errorPageView = nil
    }

    @objc private func retryLoad() {
        if let url = currentUrl {
            hideErrorPage()
            loadUrl(url)
        }
    }

    // MARK: - Back Button Handling

    public override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if parent == nil {
            // VC is being popped - check if WebView can go back first
        }
    }

    // MARK: - ComponentHost

    public func getViewController() -> UIViewController? { self }
    public func getWebView() -> Any? { webView }
    public func runOnMainThread(_ action: @escaping () -> Void) {
        DispatchQueue.main.async { action() }
    }

    // MARK: - Deinit

    deinit {
        // NSKeyValueObservation auto-invalidates on deinit; no manual removeObserver needed.
        MainActor.assumeIsolated {
            ComponentManager.shared.setHost(nil)
            BridgeTokenManager.shared.reset()
        }
    }
}

// MARK: - WKNavigationDelegate

extension CoconutWebViewController: WKNavigationDelegate {

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        progressView.isHidden = false
        progressView.progress = 0
        hideErrorPage()
        // Clear stale H5 event subscriptions so reload doesn't deliver events
        // registered by the previous page context.
        ComponentManager.shared.sharedContext.eventEmitter.clearAll()
        Logger.shared.d(tag, "Page started: \(webView.url?.absoluteString ?? "")")
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        progressView.setProgress(1.0, animated: true)
        let url = webView.url?.absoluteString ?? ""
        Logger.shared.d(tag, "Page loaded: \(url)")
        injectBridgeJavaScript()
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Logger.shared.e(tag, "Navigation failed", error)
        showErrorPage()
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Logger.shared.e(tag, "Provisional navigation failed", error)
        showErrorPage()
    }
}
