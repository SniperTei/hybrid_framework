import Foundation
import UIKit
import WebKit

public class CoconutWebViewController: UIViewController, ComponentHost {

    private let tag = "CoconutWebVC"
    public private(set) var webView: WKWebView!
    private var bridge: CoconutBridge!
    private var progressView: UIProgressView!
    private var currentUrl: String?
    private var containerView: UIView!

    public var enableDebug: Bool = false

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupWebView()
        setupBridge()

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

        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)

        containerView.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: containerView.topAnchor),
            webView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }

    // MARK: - Bridge Setup

    private func setupBridge() {
        bridge = CoconutBridge()
        webView.configuration.userContentController.add(bridge, name: "CoconutBridge")
        Logger.shared.d(tag, "Bridge setup complete")
    }

    // MARK: - Bridge JS Injection

    private func injectBridgeJavaScript() {
        let js = """
        (function() {
            if (window.__coconutInitialized) return;
            window.__coconutConfig = {
                token: '',
                signingEnabled: false,
                sharedSecret: ''
            };
            if (window.Coconut && window.Coconut._loadSecurityConfig) {
                window.Coconut._loadSecurityConfig();
            }
            window.__coconutInitialized = true;
            console.log('Coconut SDK security config injected (iOS)');
        })();
        """
        webView.evaluateJavaScript(js)
        Logger.shared.d(tag, "Bridge security config injected")
    }

    // MARK: - Public Methods

    public func loadUrl(_ url: String) {
        currentUrl = url
        guard let url = URL(string: url) else {
            Logger.shared.e(tag, "Invalid URL: \(url)")
            return
        }
        Logger.shared.d(tag, "Loading URL: \(url)")
        webView.load(URLRequest(url: url))
    }

    public func evaluateJavascript(_ script: String) {
        webView.evaluateJavaScript(script)
    }

    public func goBack() {
        if webView.canGoBack {
            webView.goBack()
        }
    }

    // MARK: - KVO

    public override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        if keyPath == #keyPath(WKWebView.estimatedProgress) {
            let progress = Float(webView.estimatedProgress)
            progressView.progress = progress
            progressView.isHidden = progress >= 1.0
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
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
        ComponentManager.shared.setHost(nil)
    }
}

// MARK: - WKNavigationDelegate

extension CoconutWebViewController: WKNavigationDelegate {

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        progressView.isHidden = false
        progressView.progress = 0
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

    private func showErrorPage() {
        let label = UILabel()
        label.text = "页面加载失败\n请检查网络连接"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .gray
        label.font = .systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
    }
}
