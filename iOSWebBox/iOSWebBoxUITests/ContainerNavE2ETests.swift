//
//  ContainerNavE2ETests.swift
//  iOSWebBoxUITests
//
//  容器导航 v3.5.0 e2e（11 场景，对齐 Android/Harmony 清单）。
//  驱动方式：XCUITest（native 按钮 / alert / 导航栏 accessibilityIdentifier
//  nav.left|nav.right）+ WKWebView content 元素（Demo.vue 按钮）。
//  前置：Vite dev server 跑在 localhost:5174（simulator 共享 Mac loopback）。
//

import XCTest
import Foundation

@MainActor
final class ContainerNavE2ETests: XCTestCase {

    private var app: XCUIApplication!

    private let forwardBtn = "forward 新容器（params+header）"
    private let templateBtn = "forward 模板容器"
    private let deadBtn = "forward 死链（错误弹窗）"
    private let closeBtn = "close({result})"
    private let subscribeResultBtn = "订阅 nav.result"
    private let subscribeButtonBtn = "订阅 nav.button"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: - Helpers

    /// Home → 「打开本地测试页面」→ 容器加载 Demo.vue（等待 H5 按钮出现）
    private func openDevServerContainer(timeout: TimeInterval = 25) {
        app.launch()
        let openBtn = app.buttons["打开本地测试页面"]
        XCTAssertTrue(openBtn.waitForExistence(timeout: 15), "Home 入口按钮未出现")
        openBtn.tap()
        XCTAssertTrue(webButton(forwardBtn).waitForExistence(timeout: timeout), "Demo.vue 未加载（Vite server 起了吗？）")
        // WebView 内容刚挂载时坐标未稳，tap 会落空（test01 教训）——稳一拍再操作
        sleep(2)
    }

    private func webButton(_ label: String) -> XCUIElement {
        app.webViews.buttons[label]
    }

    private func webText(containing text: String) -> XCUIElement {
        app.webViews.descendants(matching: .staticText)
            .matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func navBarTitle(_ text: String) -> XCUIElement {
        app.staticTexts[text]
    }

    /// 订阅 nav.result 并确认生效（run3 教训：web tap 可能静默落空且无本地
    /// 痕迹——native "Cleared 0" 证实首 tap 未达。靠 H5 面板 subscribed 回执
    /// 确认；重复订阅是覆盖语义，重试安全）
    private func subscribeNavResult() {
        for _ in 0..<3 {
            webButton(subscribeResultBtn).tap()
            if webText(containing: "subscribed").waitForExistence(timeout: 5) { return }
        }
        XCTFail("订阅 nav.result 未生效（tap 落空 ×3）")
    }

    /// 订阅 nav.result 后 forward；返回 child 的容器
    private func forwardToChild() {
        webButton(forwardBtn).tap()
        // child 是同页 Demo.vue；等它的 forward 按钮出现（present + load）
        let childForward = webButton(forwardBtn)
        XCTAssertTrue(childForward.waitForExistence(timeout: 25), "child 容器未加载")
    }

    // MARK: - 场景 ① 死链 → 白屏错误弹窗（重试 / 退出）

    func test01_deadUrl_errorDialog_retryAndExit() throws {
        openDevServerContainer()

        var alert = app.alerts["加载失败"]
        for _ in 0..<3 where !alert.waitForExistence(timeout: 8) {
            webButton(deadBtn).tap()  // WebView tap 可能落空，重试
        }
        XCTAssertTrue(alert.exists, "死链未弹错误弹窗")

        // 重试 → 仍死链 → 弹窗复现（同次加载不叠弹，重试后重新弹）。
        // 死链 = 本机关闭端口（connection refused 即时失败，run2 教训：
        // .invalid 域名经 TLS 代理时重试会握手挂起，弹窗不复现）
        alert.buttons["重试"].tap()
        alert = app.alerts["加载失败"]
        XCTAssertTrue(alert.waitForExistence(timeout: 15), "重试后弹窗未复现")

        // 退出 → child 容器关闭 → 回到父容器 Demo.vue（以父容器 forward 按钮再次可点为准）
        alert.buttons["退出"].tap()
        XCTAssertTrue(webButton(forwardBtn).waitForExistence(timeout: 15), "退出后未回到父容器")
    }

    // MARK: - 场景 ② HTTP 500 → 不弹窗（4xx/5xx 不算白屏）
    // 前置：宿主机起 500 server（iOS runner 无 Process API）：
    //   python3 -c "import http.server
    //   class H(http.server.BaseHTTPRequestHandler):
    //       def do_GET(self):
    //           self.send_response(500); self.end_headers(); self.wfile.write(b'500')
    //   http.server.HTTPServer(('127.0.0.1',8899),H).serve_forever()" &

    func test02_http500_noErrorDialog() throws {
        app.launchEnvironment["COCONUT_URL"] = "http://localhost:8899/"
        app.launch()
        // 等 WebView 消化 500 响应（渲染 server body）
        sleep(8)
        XCTAssertEqual(app.state, .runningForeground, "app 不应崩溃")
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 5),
                      "HTTP 500 不应触发白屏错误弹窗")
    }

    // MARK: - 场景 ③⑨ A→B→C forward 链 + close({result}) 对象逐级回传
    // 层级标识：A 是 AUTO 标题（document.title = coconutwebbox）；
    // B/C 是 forward header 固定标题「容器 B」——转场断言以导航栏标题为准
    //（webButton 的 existence 在 dismiss 转场中会"空等"通过，不可靠）。

    private func tapCloseAndWait(_ reveal: XCUIElement) {
        for _ in 0..<3 {
            webButton(closeBtn).tap()
            if reveal.waitForExistence(timeout: 10) { return }
        }
        XCTFail("close({result}) 未产生预期效果")
    }

    func test03_forwardChain_navResultRelay() throws {
        openDevServerContainer()

        // A 订阅 → forward B（header 固定标题「容器 B」）
        subscribeNavResult()
        forwardToChild()
        XCTAssertTrue(navBarTitle("容器 B").waitForExistence(timeout: 10), "B 未打开")

        // B 订阅 → forward C
        subscribeNavResult()
        forwardToChild()
        XCTAssertTrue(navBarTitle("容器 B").waitForExistence(timeout: 10), "C 未打开")

        // C close({result: 对象}) → C 关闭 → B resume 收 nav.result（Harmony rawValue 同型检查）。
        // 信号用 B 面板出现的 demo-close 文本（B/C 同标题，标题断言有歧义）。
        tapCloseAndWait(webText(containing: "demo-close"))

        // B close({result}) → A 收（信号用 A 的 AUTO 标题 coconutwebbox，与 B 的固定标题可区分）
        tapCloseAndWait(navBarTitle("coconutwebbox"))
        XCTAssertTrue(webText(containing: "demo-close").waitForExistence(timeout: 10),
                      "A 未收到 B 的 nav.result 对象回传")
    }

    // MARK: - 场景 ④ 根页 back → 退化关闭容器（canGoBack=false → dismiss）

    func test04_rootBack_degradesToClose() throws {
        openDevServerContainer()

        let back = app.buttons["nav.left"]
        XCTAssertTrue(back.waitForExistence(timeout: 10), "导航栏返回按钮未出现")
        back.tap()

        // 容器 dismiss → 回到 Home
        XCTAssertTrue(app.buttons["打开本地测试页面"].waitForExistence(timeout: 15),
                      "根页 back 未退化关闭容器")
    }

    // MARK: - 场景 ⑤ backToTop（native viewport scroll）ack

    func test05_backToTop_ack() throws {
        openDevServerContainer()
        webButton("backToTop").tap()
        XCTAssertTrue(webText(containing: "success").waitForExistence(timeout: 10),
                      "backToTop 未返回 success ack")
    }

    // MARK: - 场景 ⑦ 容器栈 10 层上限（第 11 次 forward 业务失败）

    func test07_stackLimit_eleventhForwardFails() throws {
        openDevServerContainer()

        // 9 次 forward 成功 → 栈深 10
        for _ in 0..<9 {
            webButton(forwardBtn).tap()
            XCTAssertTrue(webButton(forwardBtn).waitForExistence(timeout: 25), "child 容器未加载")
        }

        // 第 10 次 forward（第 11 个容器）→ success:false + "stack limit"
        webButton(forwardBtn).tap()
        XCTAssertTrue(webText(containing: "stack limit").waitForExistence(timeout: 15),
                      "栈深超限未返回业务失败（stack limit）")
    }

    // MARK: - 场景 ⑧ 自定义按钮：无订阅 no-op / 有订阅推 nav.button

    func test08_customButtons_subscriberSemantics() throws {
        openDevServerContainer()
        forwardToChild()  // header: title 容器B, rightButtonText 分享

        // child nav bar：fixed 标题 + 右侧自定义「分享」
        XCTAssertTrue(navBarTitle("容器 B").waitForExistence(timeout: 10), "header.title 未生效")
        let share = app.buttons["nav.right"]
        XCTAssertTrue(share.waitForExistence(timeout: 5), "rightButtonText 未生效")
        XCTAssertEqual(share.label, "分享")

        // 无订阅：点「分享」→ no-op（容器不关闭、页面不变）
        share.tap()
        sleep(2)
        XCTAssertTrue(navBarTitle("容器 B").exists, "无订阅点右键不应有任何效果")

        // 订阅 nav.button → 点「分享」→ H5 收 {side:right}
        //（同 subscribeNavResult 的回执确认；重复订阅覆盖语义，安全）
        for _ in 0..<3 {
            webButton(subscribeButtonBtn).tap()
            if webText(containing: "subscribed").waitForExistence(timeout: 5) { break }
        }
        share.tap()
        XCTAssertTrue(webText(containing: "\"side\"").waitForExistence(timeout: 10),
                      "订阅后未收到 nav.button {side} 事件")

        // 左键 chevron（无 leftButtonText）→ 走默认返回：B 无历史 → 关闭容器回 A
        app.buttons["nav.left"].tap()
        XCTAssertTrue(webButton(forwardBtn).waitForExistence(timeout: 15), "左键兜底返回未关闭容器")
    }

    // MARK: - 场景 ⑩ 模板命中（未注册 → Run All 场景 ⑪ 覆盖）

    func test10_templateHit_rendersSubclassUI() throws {
        openDevServerContainer()
        webButton(templateBtn).tap()

        // header.title 覆盖模板 fixed 标题（三级合并第 1 级 > 第 2 级）
        XCTAssertTrue(navBarTitle("模板容器覆盖").waitForExistence(timeout: 20), "模板容器标题未生效")
        // 模板子类自定义 UI：底部 native banner
        XCTAssertTrue(app.staticTexts["🥥 模板底部 Native Banner — DemoTemplateViewController"]
            .waitForExistence(timeout: 10), "模板底部 banner 未渲染")

        // onBack 拦截：返回 → 确认弹窗 → 留下 → 不离开
        app.buttons["nav.left"].tap()
        let alert = app.alerts["模板拦截"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "onBack 拦截弹窗未出现")
        alert.buttons["留下"].tap()
        XCTAssertTrue(navBarTitle("模板容器覆盖").waitForExistence(timeout: 5), "「留下」后应仍在模板容器")
    }

    // MARK: - 场景 ⑥⑩⑪ Run All 回归（含守卫 200007 / template 未注册 / backToTop）
    // 前置：Vite 5174 + serve-hot-update.sh（8000，Network.request 两项依赖 fixture）

    func test11_runAll_regression() throws {
        // netUrl 覆盖：iOS simulator 的 localhost = Mac loopback（fake-ip 代理
        // 环境下 LAN IP 直连被黑洞，network 两项各拖 30s 超时 → 90s 内跑不完）
        app.launchEnvironment["COCONUT_URL"] = "http://localhost:5174/?autorun=1&netUrl=http://localhost:8000/manifest.json"
        app.launch()

        // Run All 22 项（env 4 + device 1 + storage 7 + dialog 1 + event 3
        // + network 3 + navigator 3）≈ 30s。
        // 断言用导航栏标题而非 H5 面板：backToTop（最后一项）把结果面板滚出
        // 可视区后 WKWebView AX 树查不到面板文本；autorun 完成会把
        // 「结果 X/Y」（失败时附失败项名）写进 document.title，AUTO 模式
        // 导航栏原生镜像、始终可见
        let resultTitle = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS %@", "22/22")).firstMatch
        XCTAssertTrue(resultTitle.waitForExistence(timeout: 90),
                      "Run All 未全过（期望 22/22；检查 Vite 5174 + serve-hot-update.sh 8000）")
        XCTAssertEqual(app.state, .runningForeground)
    }
}
