import XCTest
import UIKit
import CoconutSDK
import CoconutNetwork
@testable import iOSWebBox

/// NavigatorComponent — forward 参数校验 / UrlGuard 守卫 / 栈深上限 / 模板
/// 未注册 / query 拼接 / header→NavConfig / close result 编码（对象回传）。
@MainActor
final class NavigatorComponentTests: XCTestCase {

    private struct LaunchCall {
        let url: String
        let navOverride: NavConfig?
        let template: CoconutWebViewController.Type?
    }

    /// 可变测试缝（closures 捕获该引用）
    private final class Seams {
        var depth = 0
        var launched: [LaunchCall] = []
        var templates: [String: CoconutWebViewController.Type] = [:]
    }

    private var seams: Seams!
    private var component: NavigatorComponent!
    private var context: ComponentContext!
    private var hostVC: CoconutWebViewController!
    private var savedAllowedDomains: [String] = []

    override func setUp() async throws {
        let s = Seams()
        seams = s
        component = NavigatorComponent(
            stackDepthSupplier: { s.depth },
            launcher: { url, navOverride, template, _ in
                s.launched.append(LaunchCall(url: url, navOverride: navOverride, template: template))
            },
            templateResolver: { s.templates }
        )

        // ComponentContext.host 是 internal —— 借道单例 manager 注入 host
        // （tearDown 还原，避免污染同批其他测试）。
        ComponentManager.shared.setApplicationContext(UIApplication.shared)
        hostVC = CoconutWebViewController()
        ComponentManager.shared.setHost(hostVC)
        context = ComponentManager.shared.sharedContext
        try await component.initComponent(context: context)

        savedAllowedDomains = CoconutSDK.getConfig().allowedDomains
        CoconutSDK.configure { $0.allowedDomains = [] }  // 空白名单 = 放行所有
    }

    override func tearDown() async throws {
        ComponentManager.shared.setHost(nil)
        _ = NavResultBus.consume()
        await component.cleanup()
        CoconutSDK.configure { $0.allowedDomains = self.savedAllowedDomains }
        seams = nil
        component = nil
        context = nil
        hostVC = nil
    }

    // MARK: - forward: 校验

    func test_forward_missingUrl_throws200007() async {
        await assertBridgeError(code: "200007") {
            try await self.component.handle(function: "forward", params: [:])
        }
    }

    func test_forward_disallowedScheme_throws200007() async {
        await assertBridgeError(code: "200007") {
            try await self.component.handle(function: "forward", params: ["url": "ftp://example.com/x"])
        }
        XCTAssertTrue(seams.launched.isEmpty)
    }

    func test_forward_blockedDomain_throws200007() async {
        CoconutSDK.configure { $0.allowedDomains = ["allowed.com"] }
        await assertBridgeError(code: "200007") {
            try await self.component.handle(function: "forward", params: ["url": "https://evil.com/page"])
        }
        XCTAssertTrue(seams.launched.isEmpty)
    }

    func test_forward_whitelistedDomain_launches() async throws {
        CoconutSDK.configure { $0.allowedDomains = ["allowed.com"] }
        _ = try await component.handle(function: "forward", params: ["url": "https://allowed.com/page"])
        XCTAssertEqual(1, seams.launched.count)
        XCTAssertEqual("https://allowed.com/page", seams.launched[0].url)
    }

    // MARK: - forward: coconut:// 守卫旁路

    func test_forward_coconutScheme_bypassesGuard() async throws {
        CoconutSDK.configure { $0.allowedDomains = ["allowed.com"] }
        _ = try await component.handle(function: "forward", params: ["url": "coconut://demo/index.html"])
        XCTAssertEqual(1, seams.launched.count)
        XCTAssertEqual("coconut://demo/index.html", seams.launched[0].url)
    }

    // MARK: - forward: 栈深 / 模板

    func test_forward_stackLimit_businessFailure() async throws {
        seams.depth = NavigatorComponent.MAX_STACK_DEPTH
        let result = try await component.handle(function: "forward", params: ["url": "https://example.com/"])
        XCTAssertEqual(false, result["success"] as? Bool)
        XCTAssertTrue((result["message"] as? String ?? "").contains("stack limit"))
        XCTAssertTrue(seams.launched.isEmpty)
    }

    func test_forward_templateNotRegistered_businessFailure() async throws {
        seams.templates = [:]
        let result = try await component.handle(function: "forward",
                                                 params: ["url": "https://example.com/", "template": "demo"])
        XCTAssertEqual(false, result["success"] as? Bool)
        XCTAssertTrue((result["message"] as? String ?? "").contains("template not registered"))
        XCTAssertTrue(seams.launched.isEmpty, "未注册模板绝不静默回退到标准容器")
    }

    func test_forward_templateHit_launchesTemplateType() async throws {
        seams.templates = ["demo": CoconutWebViewController.self]
        _ = try await component.handle(function: "forward",
                                        params: ["url": "https://example.com/", "template": "demo"])
        XCTAssertEqual(1, seams.launched.count)
        XCTAssertTrue(seams.launched[0].template === CoconutWebViewController.self)
    }

    // MARK: - forward: params / header

    func test_forward_paramsFlattenIntoQuery() async throws {
        let result = try await component.handle(
            function: "forward",
            params: ["url": "https://example.com/page", "params": ["a": 1, "b": "x y", "c": true]])
        XCTAssertEqual(true, result["success"] as? Bool)
        guard !seams.launched.isEmpty else {
            XCTFail("launcher not called")
            return
        }
        let url = seams.launched[0].url
        XCTAssertTrue(url.hasPrefix("https://example.com/page?"))
        XCTAssertTrue(url.contains("a=1"))
        XCTAssertTrue(url.contains("b=x%20y"))
        XCTAssertTrue(url.contains("c=true"))
    }

    func test_forward_paramsMergeWithExistingQuery() async throws {
        _ = try await component.handle(
            function: "forward",
            params: ["url": "https://example.com/page?z=9", "params": ["a": 1]])
        XCTAssertEqual("https://example.com/page?z=9&a=1", seams.launched[0].url)
    }

    func test_forward_headerBecomesNavOverride() async throws {
        _ = try await component.handle(
            function: "forward",
            params: [
                "url": "https://example.com/",
                "header": ["visible": false, "title": "订单详情", "closePolicy": "always"],
            ])
        let nav = seams.launched[0].navOverride
        XCTAssertNotNil(nav)
        XCTAssertEqual(false, nav?.visible)
        XCTAssertEqual(.fixed("订单详情"), nav?.titleMode)
        XCTAssertEqual(.always, nav?.closePolicy)
    }

    func test_forward_malformedHeader_isIgnored() async throws {
        // header 不是 kv 对象（比如字符串）→ 忽略，不炸启动
        _ = try await component.handle(
            function: "forward",
            params: ["url": "https://example.com/", "header": "not-an-object"])
        XCTAssertNil(seams.launched[0].navOverride)
    }

    // MARK: - close({result})：对象回传（Harmony rawValue 前车之鉴）

    func test_close_objectResult_roundTripsThroughBus() async throws {
        let result = try await component.handle(
            function: "close",
            params: ["result": ["orderId": 123, "flag": true, "note": "ok"]])
        XCTAssertEqual(true, result["success"] as? Bool)

        let raw = NavResultBus.consume()
        XCTAssertNotNil(raw)
        // JSON 文本 → 解析回真实 JSON 值（字典直取，无 rawValue 式丢失）
        let data = raw?.data(using: .utf8) ?? Data()
        let parsed = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        XCTAssertEqual(123, parsed?["orderId"] as? Int)
        XCTAssertEqual(true, parsed?["flag"] as? Bool)
        XCTAssertEqual("ok", parsed?["note"] as? String)
    }

    func test_close_nestedObjectResult_survives() async throws {
        _ = try await component.handle(
            function: "close",
            params: ["result": ["user": ["id": 7], "tags": ["a", "b"]]])
        let data = (NavResultBus.consume() ?? "").data(using: .utf8) ?? Data()
        let parsed = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let user = parsed?["user"] as? [String: Any]
        XCTAssertEqual(7, user?["id"] as? Int)
        XCTAssertEqual(["a", "b"], parsed?["tags"] as? [String])
    }

    func test_close_stringResult_staysRaw() async throws {
        _ = try await component.handle(function: "close", params: ["result": "hello"])
        XCTAssertEqual("hello", NavResultBus.consume())
    }

    func test_close_withoutResult_doesNotPost() async throws {
        _ = try await component.handle(function: "close", params: [:])
        XCTAssertNil(NavResultBus.consume())
    }

    // MARK: - back / backToTop 失败路径（无 host / 无 webview）

    func test_backToTop_withoutLoadedWebView_businessFailure() async throws {
        // hostVC 未 loadView → currentWebView 为 nil
        let result = try await component.handle(function: "backToTop", params: [:])
        XCTAssertEqual(false, result["success"] as? Bool)
        XCTAssertTrue((result["message"] as? String ?? "").contains("no active webview"))
    }

    func test_forward_withoutHost_businessFailure() async throws {
        ComponentManager.shared.setHost(nil)
        let result = try await component.handle(function: "forward", params: ["url": "https://example.com/"])
        XCTAssertEqual(false, result["success"] as? Bool)
        XCTAssertTrue((result["message"] as? String ?? "").contains("no active container"))
        XCTAssertTrue(seams.launched.isEmpty)
    }

    // MARK: - helpers

    /// 隔离实验：不经 handle()，直调 appendQuery。
    /// ⚠️ 不要在同步测试方法里创建局部 NavigatorComponent —— @MainActor 对象在
    /// sync 方法体末尾析构会踩 Swift 运行时 back-deployed deinit + XCTest
    /// task-local 作用域的 malloc bug（复用 self.component，它在 async tearDown
    /// 释放，路径安全）。
    func test_appendQuery_standalone() {
        let out = component.appendQuery("https://example.com/page", params: ["a": 1, "b": "x y", "c": true])
        // 字典迭代序不定 → 拆开逐对断言
        XCTAssertTrue(out.hasPrefix("https://example.com/page?"))
        let pairs = Set(out.dropFirst("https://example.com/page?".count).split(separator: "&").map(String.init))
        XCTAssertEqual(["a=1", "b=x%20y", "c=true"], pairs.sorted())
    }

    private func assertBridgeError(code: String, line: UInt = #line,
                                   _ body: () async throws -> [String: Any]) async {
        do {
            _ = try await body()
            XCTFail("expected ComponentException \(code)", line: line)
        } catch let e as ComponentException {
            XCTAssertEqual(code, e.code, line: line)
        } catch {
            XCTFail("unexpected error type: \(error)", line: line)
        }
    }
}
