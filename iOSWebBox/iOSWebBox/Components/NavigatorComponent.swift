import Foundation
import UIKit
import WebKit
import CoconutSDK
import CoconutNetwork

/// Topic pushed to H5 when a custom nav-bar button is tapped ({side: left|right}).
public let NAV_TOPIC_BUTTON = "nav.button"

/// Topic pushed to the previous container's H5 when a child closes with a result ({result}).
public let NAV_TOPIC_RESULT = "nav.result"

/**
 * Navigator Component — H5 opens/controls native containers (第 6 个组件).
 *
 * - forward({template?, url*, params?, header?}): open a new container.
 *   url passes the allowedDomains guard (coconut:// offline packages are
 *   scheme-whitelisted); params flatten into the query string; header
 *   becomes the per-open NavConfig override. Container stack capped at
 *   MAX_STACK_DEPTH; unregistered templates fail loudly — never silently
 *   fall back to the standard container.
 * - back(): same path as nav-bar back (goBack, degrade to close) — routes
 *   through CoconutWebViewController.handleBack (onBack hook included).
 * - backToTop(): native viewport scroll (WebView is the scroll host).
 * - close({result?}): close this container even with history; a result is
 *   delivered to the previous container as the `nav.result` event on its
 *   next resume (NavResultBus single slot).
 *
 * Failure conventions: guard/validation → bridge error 200007 (same
 * semantics as network.request); business failures (stack limit, template
 * 未注册, no host) → code 000000 + success:false in the payload.
 *
 * Test seams: stack depth supplier, launcher and template resolver are
 * injectable; defaults read CoconutWebViewController.stackDepth(), a plain
 * fullScreen present and the template registry respectively.
 */
@MainActor
public final class NavigatorComponent: BaseComponent {

    override public var name: String { "navigator" }
    override public var version: String { "1.0.0" }
    override public var pluginDescription: String { "Container navigation component (forward/back/backToTop/close)" }
    override public var methods: [String] { ["forward", "back", "backToTop", "close"] }

    /// Container stack cap (self-forward loop protection).
    public static let MAX_STACK_DEPTH = 10

    private var context: ComponentContext?

    // ---- Test seams ----

    private let stackDepthSupplier: () -> Int
    private let launcher: (String, NavConfig?, CoconutWebViewController.Type?, UIViewController) -> Void
    private let templateResolver: () -> [String: CoconutWebViewController.Type]

    /// 默认构造：真实 stackDepth + plain present + 模板注册表（Phase 4 接入）
    override public convenience init() {
        self.init(
            stackDepthSupplier: { CoconutWebViewController.stackDepth() },
            launcher: { url, navOverride, templateType, from in
                NavigatorComponent.defaultLauncher(url: url,
                                                   navOverride: navOverride,
                                                   templateType: templateType,
                                                   from: from)
            },
            templateResolver: { NavigatorComponent.loadTemplates() }
        )
    }

    /// 测试注入构造
    public init(
        stackDepthSupplier: @escaping () -> Int,
        launcher: @escaping (String, NavConfig?, CoconutWebViewController.Type?, UIViewController) -> Void,
        templateResolver: @escaping () -> [String: CoconutWebViewController.Type]
    ) {
        self.stackDepthSupplier = stackDepthSupplier
        self.launcher = launcher
        self.templateResolver = templateResolver
        super.init()
    }

    override public func onInit(context: ComponentContext) async {
        self.context = context
    }

    override public func handle(function: String, params: [String: Any]?) async throws -> [String: Any] {
        switch function {
        case "forward": return try await forward(params)
        case "back": return back()
        case "backToTop": return backToTop()
        case "close": return close(params)
        default: try functionNotSupportedError(function)
        }
    }

    // ---- forward ----

    private func forward(_ params: [String: Any]?) async throws -> [String: Any] {
        let url = getParam(params, "url")
        if url.isEmpty {
            try error("200007", "url is required")
        }

        // Outbound guard (container has no address bar — phishing defense):
        // http(s) URLs go through UrlGuard exactly like network.request;
        // coconut:// offline packages are scheme-whitelisted (moduleId is not
        // a domain; they ride the app-internal scheme handler).
        if !url.hasPrefix("coconut://") {
            let domains = CoconutSDK.isInitialized ? CoconutSDK.getConfig().allowedDomains : []
            let guardResult = UrlGuard.validate(url, allowedDomains: domains)
            if !guardResult.allowed {
                try error("200007", "forward blocked: \(guardResult.reason)")
            }
        }

        if stackDepthSupplier() >= Self.MAX_STACK_DEPTH {
            return businessFailure("container stack limit reached (\(Self.MAX_STACK_DEPTH))")
        }

        var templateType: CoconutWebViewController.Type?
        let templateName = getParam(params, "template")
        if !templateName.isEmpty {
            guard let resolved = templateResolver()[templateName] else {
                return businessFailure("template not registered: \(templateName)")
            }
            templateType = resolved
        }

        guard let context else { return businessFailure("component not initialized") }
        guard let from = context.currentViewController else { return businessFailure("no active container") }

        let finalUrl = appendQuery(url, params: params?["params"] as? [String: Any])
        launcher(finalUrl, parseHeader(params?["header"]), templateType, from)
        return ack()
    }

    /// Flatten a flat kv object into a URL-encoded query string and append it
    /// (merged with `&` when the url already carries a query).
    func appendQuery(_ url: String, params: [String: Any]?) -> String {
        guard let params, !params.isEmpty else { return url }
        var allowedCharacters = CharacterSet.alphanumerics
        allowedCharacters.insert(charactersIn: "-._~")
        let query = params.map { k, v in
            let value: String
            if let s = v as? String {
                value = s
            } else if let dict = v as? [String: Any],
                      let data = try? JSONSerialization.data(withJSONObject: dict),
                      let json = String(data: data, encoding: .utf8) {
                // ⚠️ 只对显式集合类型调 data(withJSONObject:)：
                // isValidJSONObject 对顶层 NSNumber 标量返回 true，但写入时抛
                // ObjC 异常（Swift try? 接不住）→ 进程崩溃（单测抓出）。
                value = json
            } else if let arr = v as? [Any],
                      let data = try? JSONSerialization.data(withJSONObject: arr),
                      let json = String(data: data, encoding: .utf8) {
                value = json
            } else {
                // 标量（Int/Bool/Float）：插值即文本（1 / true / 1.5）
                value = "\(v)"
            }
            return "\(k.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? k)=\(value.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? value)"
        }.joined(separator: "&")
        return url.contains("?") ? "\(url)&\(query)" : "\(url)?\(query)"
    }

    /// header → per-open NavConfig override. [String: Any] comes straight
    /// from JSONSerialization (dictionary direct access — no Harmony rawValue
    /// regex pitfall); re-serialized to JSON for parseOverride's tolerances.
    private func parseHeader(_ header: Any?) -> NavConfig? {
        guard let obj = header as? [String: Any],
              JSONSerialization.isValidJSONObject(obj),
              let data = try? JSONSerialization.data(withJSONObject: obj),
              let json = String(data: data, encoding: .utf8) else { return nil }
        return NavConfig.parseOverride(json)
    }

    /// Plain fullScreen present — a fresh VC instance per forward, no
    /// Android NEW_TASK same-class dedupe equivalent on iOS.
    private static func defaultLauncher(url: String, navOverride: NavConfig?, templateType: CoconutWebViewController.Type?, from: UIViewController) {
        let vc = templateType?.init() ?? CoconutWebViewController()
        vc.navOverride = navOverride
        vc.modalPresentationStyle = .fullScreen
        from.present(vc, animated: true) {
            vc.loadUrl(url)
        }
    }

    // ---- back / backToTop / close ----

    private func back() -> [String: Any] {
        guard let context else { return businessFailure("component not initialized") }
        guard let vc = hostContainer(context) else { return businessFailure("no active container") }
        vc.handleBack()
        return ack()
    }

    private func backToTop() -> [String: Any] {
        guard let context else { return businessFailure("component not initialized") }
        guard let webView = context.currentWebView else { return businessFailure("no active webview") }
        // Native viewport scroll — JS window.scrollTo can't find the right
        // scroll host inside inner scrollable containers.
        webView.scrollView.setContentOffset(.zero, animated: true)
        return ack()
    }

    private func close(_ params: [String: Any]?) -> [String: Any] {
        guard let context else { return businessFailure("component not initialized") }
        guard let vc = hostContainer(context) else { return businessFailure("no active container") }
        if let result = params?["result"] {
            NavResultBus.post(Self.encodeResult(result))
        }
        vc.closeContainer()
        return ack()
    }

    private func hostContainer(_ context: ComponentContext) -> CoconutWebViewController? {
        context.currentViewController as? CoconutWebViewController
    }

    /// Object/array results → JSON text (parsed back to a real JSON value on
    /// drain); string primitives stay raw text. Harmony rawValue lesson:
    /// result IS an object — dictionary direct access, no primitive-only
    /// extraction paths.
    static func encodeResult(_ result: Any) -> String {
        // 与 appendQuery 同款守卫：只对集合类型调 data(withJSONObject:)，
        // 标量走插值（isValidJSONObject 对顶层 NSNumber 误报 true → ObjC 异常）。
        if let dict = result as? [String: Any],
           let data = try? JSONSerialization.data(withJSONObject: dict),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        if let arr = result as? [Any],
           let data = try? JSONSerialization.data(withJSONObject: arr),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        if let s = result as? String { return s }
        return "\(result)"
    }

    // ---- templates ----

    private static func loadTemplates() -> [String: CoconutWebViewController.Type] {
        // Phase 4 wires the bundle coconut_templates.json registry here.
        TemplateRegistry.shared.resolve()
    }

    // ---- helpers ----

    private func businessFailure(_ message: String) -> [String: Any] {
        ["success": false, "message": message]
    }

    private func ack() -> [String: Any] {
        ["success": true]
    }
}
