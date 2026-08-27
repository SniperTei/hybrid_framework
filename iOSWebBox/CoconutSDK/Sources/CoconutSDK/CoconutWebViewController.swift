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
    private var navBarView: CoconutNavBarView?
    private var progressObservation: NSKeyValueObservation?
    private var titleObservation: NSKeyValueObservation?

    public var enableDebug: Bool = false

    // ---- Navigation bar config (v3.5.0 container-nav) ----

    /// Per-open override tier (forward header / native callers), merged on top
    /// of `defaultNavConfig` and CoconutConfig.nav in viewDidLoad.
    public var navOverride: NavConfig?

    /// Template-subclass code-level default (middle tier of the three-tier
    /// chain: CoconutConfig.nav < this < navOverride). All-nil by default →
    /// pure inherit. Override in subclasses:
    /// `override var defaultNavConfig: NavConfig { NavConfig(titleMode: .fixed("模板页")) }`
    open var defaultNavConfig: NavConfig { NavConfig() }

    /// Effective config, resolved once in viewDidLoad before setupUI.
    public private(set) var navConfig: NavConfig = NavConfig.default()

    /// Per-instance error-dialog override; nil = CoconutConfig.enableErrorDialog.
    public var enableErrorDialog: Bool?

    /// True between didFinish and the next didStart (token-refresh gate on claim).
    private var pageLoaded = false

    private var errorDialogVisible = false

    // MARK: - Delegate hooks (template subclasses)

    /// Back interception: return true to consume the tap (default back
    /// semantics NOT performed), false to fall through.
    open func onBack() -> Bool { false }

    /// Main-frame network-level load failure (also fires with the error
    /// dialog disabled — observability for template subclasses).
    open func onLoadFail(url: String, error: Error) {}

    /// document.title change (fires in both AUTO and FIXED nav modes).
    open func onTitleChange(title: String) {}

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        resolveNavConfig()
        setupUI()
        setupWebView()
        setupBridge()
        applySecurityConfig()

        if enableDebug {
            CoconutSDK.configure { config in
                config.debugMode = true
            }
        }
        // Host claim + token + event wiring happen in viewWillAppear
        // (resume-claim model): viewDidLoad-time claiming lets a stacked
        // container B steal the singleton host from A.
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        claimHost()
    }

    /// Resume-claim: the top-of-stack container owns the singleton host,
    /// bridge token and event jsExecutor. Claiming on appear means modal
    /// LIFO order keeps routing to the visible container with zero extra
    /// plumbing (B over A: B claims; B dismissed: A re-claims).
    private func claimHost() {
        guard let webView else { return }

        ComponentManager.shared.setHost(self)
        if BridgeTokenManager.shared.enabled {
            BridgeTokenManager.shared.generateToken()
        }
        ComponentManager.shared.sharedContext.eventEmitter.jsExecutor = WebViewJSExecutor(webView: webView)

        // A re-appeared page still holds its old token in JS; re-inject to
        // refresh (injectBridgeJavaScript re-runs config on every pass).
        if pageLoaded {
            injectBridgeJavaScript()
        }
        Logger.shared.d(tag, "Host claimed (self)")
    }

    // MARK: - NavConfig resolution

    /// CoconutConfig.nav (global) ← defaultNavConfig (template subclass)
    /// ← navOverride (forward header / native caller). Field-by-field.
    private func resolveNavConfig() {
        var cfg = CoconutConfig.shared.nav
        cfg = NavConfig.merge(base: cfg, override: defaultNavConfig)
        if let navOverride {
            cfg = NavConfig.merge(base: cfg, override: navOverride)
        }
        navConfig = cfg
        Logger.shared.d(tag, "NavConfig resolved: visible=\(String(describing: navConfig.visible)), titleMode=\(String(describing: navConfig.titleMode)), closePolicy=\(String(describing: navConfig.closePolicy))")
    }

    private var resolvedEnableErrorDialog: Bool {
        enableErrorDialog ?? CoconutConfig.shared.enableErrorDialog
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = .white

        if navConfig.visible == true {
            let bar = CoconutNavBarView()
            bar.translatesAutoresizingMaskIntoConstraints = false
            bar.onLeftTap = { [weak self] in self?.handleLeftTap() }
            bar.onRightTap = { [weak self] in self?.handleRightTap() }
            view.addSubview(bar)
            NSLayoutConstraint.activate([
                bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                bar.heightAnchor.constraint(equalToConstant: 44),
            ])
            navBarView = bar

            if let text = navConfig.leftButtonText {
                bar.setLeftText(text)
            } else {
                bar.setLeftBack()
            }
            if case .fixed(let text) = navConfig.titleMode {
                bar.setTitle(text)
            }
            refreshNavButtons()
        }

        containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        progressView = UIProgressView(progressViewStyle: .default)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progress = 0
        progressView.isHidden = true
        view.addSubview(progressView)

        let barBottom = navBarView?.bottomAnchor ?? view.safeAreaLayoutGuide.topAnchor
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: barBottom),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            progressView.topAnchor.constraint(equalTo: barBottom),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2)
        ])
    }

    /// Recompute the right nav slot: custom action text when configured,
    /// otherwise × when NavConfig.shouldShowClose says so. Called on history
    /// changes (didCommit/didFinish — WKWebView has no doUpdateVisitedHistory).
    private func refreshNavButtons() {
        guard let bar = navBarView else { return }
        let canGoBack = webView?.canGoBack ?? false
        if let text = navConfig.rightButtonText {
            bar.setRightText(text)
        } else if navConfig.shouldShowClose(canGoBack: canGoBack) {
            bar.setRightClose()
        } else {
            bar.hideRight()
        }
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

        // Offline package serving: coconut://<moduleId>/<path> → sandbox > bundle
        config.setURLSchemeHandler(CoconutSchemeHandler(), forURLScheme: "coconut")

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

        // AUTO title mode syncs document.title into the nav bar; FIXED keeps
        // whatever the config resolved.
        titleObservation = wv.observe(\.title, options: [.new]) { [weak self] _, change in
            guard let title = change.newValue ?? nil, !title.isEmpty else { return }
            DispatchQueue.main.async { [weak self] in
                self?.handleTitleChange(title)
            }
        }

        containerView.addSubview(wv)
        NSLayoutConstraint.activate([
            wv.topAnchor.constraint(equalTo: containerView.topAnchor),
            wv.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }

    private func handleTitleChange(_ title: String) {
        if case .fixed = navConfig.titleMode {
            // FIXED keeps the configured text
        } else {
            navBarView?.setTitle(title)
        }
        onTitleChange(title: title)
    }

    // MARK: - Bridge Setup

    private func setupBridge() {
        bridge = CoconutBridge()
        if let webView = webView {
            webView.configuration.userContentController.add(bridge, name: "CoconutBridge")
        }
        // EventEmitter jsExecutor wiring moved to claimHost (resume-claim).
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
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? Bundle.main.bundleIdentifier
            ?? "unknown"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let capabilities = ComponentManager.shared.getCapabilities()

        let js = Self.bridgeBootstrapJS(
            token: token,
            appName: appName,
            appVersion: appVersion,
            hybridVersion: "3",
            capabilities: capabilities
        )
        webView.evaluateJavaScript(js)
        Logger.shared.d(tag, "Bridge config injected (token: \(token.prefix(8))..., app: \(appName) \(appVersion), caps: \(capabilities)")
    }

    /// Builds the bootstrap JS injected into the page after navigation finishes.
    /// Extracted to a static method so the script shape is unit-testable without a WebView.
    private static func bridgeBootstrapJS(token: String, appName: String, appVersion: String, hybridVersion: String, capabilities: [String: [String]]) -> String {
        // Build config object as JSON to avoid quote-escaping pitfalls in app names.
        let config: [String: Any] = [
            "token": token,
            "appName": appName,
            "appVersion": appVersion,
            "hybridVersion": hybridVersion,
            "capabilities": capabilities
        ]
        let data = (try? JSONSerialization.data(withJSONObject: config)) ?? Data()
        let configJson = String(data: data, encoding: .utf8) ?? "{}"
        return """
        (function() {
            // Config must refresh on EVERY injection: the resume-claim model
            // regenerates the bridge token when this container regains host,
            // and a page keeping the stale token fails every call with 300004.
            window.__coconutConfig = \(configJson);
            if (window.coconut && window.coconut._loadSecurityConfig) {
                window.coconut._loadSecurityConfig();
            }
            if (window.__coconutInitialized) return;
            window.__coconutInitialized = true;
            console.log('Coconut SDK config injected (iOS)');
        })();
        """
    }

    // MARK: - Public Methods

    public func loadUrl(_ urlString: String) {
        currentUrl = urlString
        guard let url = URL(string: urlString) else {
            Logger.shared.e(tag, "Invalid URL: \(urlString)")
            return
        }
        Logger.shared.d(tag, "Loading URL: \(urlString)")
        // For file:// URLs, grant read access to the parent directory so the
        // page can load sibling resources (e.g. <script src="./coconut.js">).
        if url.isFileURL {
            webView?.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            webView?.load(URLRequest(url: url))
        }
    }

    public func evaluateJavascript(_ script: String) {
        webView?.evaluateJavaScript(script)
    }

    public func goBack() {
        guard let webView = webView, webView.canGoBack else { return }
        webView.goBack()
    }

    /// Native viewport scroll — JS window.scrollTo can't find the right
    /// scroll host inside inner scrollable containers.
    public func backToTop() {
        webView?.scrollView.setContentOffset(.zero, animated: true)
    }

    // MARK: - Back / close semantics

    /**
     * Unified back semantics: H5 history first, degrade to closing the
     * container. Nav-bar back and coconut.navigator.back() both route here.
     * `onBack()` interception runs first (template subclasses).
     */
    public func handleBack() {
        if onBack() { return }
        performDefaultBack()
    }

    private func performDefaultBack() {
        if let webView = webView, webView.canGoBack {
            webView.goBack()
        } else {
            closeContainer()
        }
    }

    /// Close this container. Dismisses when presented; warns when it is the
    /// window root (e.g. COCONUT_URL e2e hook — the host owns that case).
    public func closeContainer() {
        if presentingViewController != nil {
            dismiss(animated: true)
        } else {
            Logger.shared.w(tag, "close: no presenting VC (root container) — nothing to close")
        }
    }

    /// Left slot tap: custom text + H5 nav.button subscriber → push the event
    /// only (page decides whether to call back); otherwise default back
    /// semantics (prevents the "custom text but forgot to subscribe"
    /// dead-button trap). Plain chevron always goes through default back.
    private func handleLeftTap() {
        if navConfig.leftButtonText != nil,
           let emitter = ComponentManager.shared.sharedContext?.eventEmitter,
           emitter.has(topic: "nav.button") {
            emitter.emit(topic: "nav.button", data: ["side": "left"])
            return
        }
        handleBack()
    }

    /// Right slot tap: H5 nav.button subscriber → push the event; no
    /// subscriber → no-op + warn (close capability is yielded to the custom
    /// action, but the back button still exits).
    private func handleRightTap() {
        guard let emitter = ComponentManager.shared.sharedContext?.eventEmitter,
              emitter.has(topic: "nav.button") else {
            Logger.shared.w(tag, "nav.button right tap with no subscriber — no-op")
            return
        }
        emitter.emit(topic: "nav.button", data: ["side": "right"])
    }

    // MARK: - Error Dialog (white-screen rescue)

    /// Native error dialog on main-frame network-level load failure.
    /// 重试 = reload the original URL; 退出 = close the container.
    /// Independent of nav-bar visibility (a hidden bar still gets rescue);
    /// no stacking within one load attempt (didStartProvisional resets).
    /// HTTP 4xx/5xx responses render the server error body and are NOT
    /// treated as white screens (WKWebView never reports them as failures).
    private func handleLoadFailure(_ error: Error) {
        // NSURLErrorCancelled accompanies every programmatic navigation
        // (goBack/reload) — not a user-facing failure.
        if (error as NSError).code == NSURLErrorCancelled { return }

        onLoadFail(url: currentUrl ?? "", error: error)

        guard resolvedEnableErrorDialog, !errorDialogVisible else { return }
        errorDialogVisible = true

        let alert = UIAlertController(title: "加载失败", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "重试", style: .default) { [weak self] _ in
            self?.errorDialogVisible = false
            if let url = self?.currentUrl {
                self?.loadUrl(url)
            }
        })
        alert.addAction(UIAlertAction(title: "退出", style: .cancel) { [weak self] _ in
            self?.errorDialogVisible = false
            self?.closeContainer()
        })
        present(alert, animated: true)
        Logger.shared.d(tag, "Error dialog shown")
    }

    private func dismissErrorDialog() {
        errorDialogVisible = false
        if let alert = presentedViewController as? UIAlertController {
            alert.dismiss(animated: false)
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
            // Identity guard: only the current host holder tears down shared
            // bridge state. Without this, a dismissed backgrounded container B
            // would null the host / reset the token that the already-claimed
            // container A depends on (calls going silent, 300004 errors).
            if ComponentManager.shared.sharedContext?.host === self {
                ComponentManager.shared.setHost(nil)
                BridgeTokenManager.shared.reset()
            }
        }
    }
}

// MARK: - WKNavigationDelegate

extension CoconutWebViewController: WKNavigationDelegate {

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        progressView.isHidden = false
        progressView.progress = 0
        pageLoaded = false
        dismissErrorDialog()
        // Clear stale H5 event subscriptions so reload doesn't deliver events
        // registered by the previous page context.
        ComponentManager.shared.sharedContext.eventEmitter.clearAll()
        Logger.shared.d(tag, "Page started: \(webView.url?.absoluteString ?? "")")
    }

    public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        // SPA route changes don't always re-fire the title KVO; re-read on
        // commit as the mitigation. Also refresh ×-visibility (canGoBack).
        if let title = webView.title, !title.isEmpty {
            handleTitleChange(title)
        }
        refreshNavButtons()
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        progressView.setProgress(1.0, animated: true)
        pageLoaded = true
        let url = webView.url?.absoluteString ?? ""
        Logger.shared.d(tag, "Page loaded: \(url)")
        injectBridgeJavaScript()
        refreshNavButtons()
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Logger.shared.e(tag, "Navigation failed", error)
        handleLoadFailure(error)
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Logger.shared.e(tag, "Provisional navigation failed", error)
        handleLoadFailure(error)
    }
}
