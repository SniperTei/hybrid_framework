//
//  H5AppE2ETests.swift
//  iOSWebBoxUITests
//
//  真实业务试点 Phase 4 e2e：native 首页「H5 App (4 tab)」按钮 →
//  coconut://h5app/index.html 离线包 → 4 tab 渲染 / 首页 bridge 数据
//  （env + 能力矩阵 8✓，WebBox 注册 update）/ 发现页断 Sniper 降级不白屏。
//  离线包随 CoconutSDK SPM resources 打包，无需 dev server。
//

import XCTest
import Foundation

@MainActor
final class H5AppE2ETests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func webButton(_ label: String) -> XCUIElement {
        app.webViews.buttons[label]
    }

    /// TabBar 是 <a> 链接（TabBar.vue），WKWebView AX 不暴露为 button；
    /// 按精确 staticText 点（tab 标签就是 <span> 文本）
    private func tabTap(_ label: String) {
        let tab = app.webViews.staticTexts[label]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "tab 「\(label)」未找到")
        tab.tap()
        sleep(1)
    }

    private func webText(containing text: String) -> XCUIElement {
        app.webViews.descendants(matching: .staticText)
            .matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// Home → H5 App → 等 4 tab 首屏（TabBar 在页底，WKWebView AX 需坐标稳定）
    private func openH5App() {
        app.launch()
        let btn = app.buttons["H5 App (4 tab)"]
        if !btn.waitForExistence(timeout: 10) {
            app.swipeUp()
            XCTAssertTrue(btn.waitForExistence(timeout: 5), "Home H5 App 入口未出现")
        }
        btn.tap()
        XCTAssertTrue(webText(containing: "容器仪表盘").waitForExistence(timeout: 25),
                      "h5app 首页未渲染（coconut://h5app/index.html 加载失败？）")
        sleep(2)  // WebView 坐标稳定（ContainerNav test01 教训）
    }

    /// 入口 + 4 tab 切换渲染
    func test01_entryAndFourTabs() {
        openH5App()
        XCTAssertTrue(webText(containing: "容器仪表盘").exists, "首页标题未渲染")
        for tab in ["发现", "AI", "我的"] { tabTap(tab) }
        tabTap("首页")
        XCTAssertTrue(webText(containing: "容器仪表盘").waitForExistence(timeout: 5), "切回首页失败")
    }

    /// 首页 bridge 数据：env 卡（SDK v3.5.1，config 注入证据）+ 能力矩阵 8✓
    /// （WebBox 注册全部 7 组件，update.check 也应为 ✓）
    func test02_homeBridgeDataAndCapabilityMatrix() {
        openH5App()
        // env 卡：iOS 注入早于 mount，首轮即有
        let sdkLine = webText(containing: "SDK：")
        XCTAssertTrue(sdkLine.waitForExistence(timeout: 10), "env 卡未渲染")
        XCTAssertTrue(sdkLine.label.contains("3.5.1"), "SDK 版本应 3.5.1，实际：\(sdkLine.label)")
        // 能力矩阵在页底：swipe 到可见（WKWebView AX 不暴露屏幕外文本）
        var found = false
        for _ in 0..<5 {
            if webText(containing: "update.check").exists { found = true; break }
            app.swipeUp()
            sleep(1)
        }
        XCTAssertTrue(found, "能力矩阵未滚动到可见")
        sleep(1)
        let cross = app.webViews.descendants(matching: .staticText)
            .matching(NSPredicate(format: "label == '✗'")).firstMatch
        XCTAssertFalse(cross.exists, "能力矩阵存在 ✗（应有 8✓，update 在 WebBox 已注册）")
    }

    /// 发现页：默认 apiBase（127.0.0.1:8041）无 Sniper 服务 → 降级不白屏
    /// （列表失败卡 + 重试按钮 + 事件订阅区仍渲染）
    func test03_discoverDegradedNotBlank() {
        openH5App()
        tabTap("发现")
        // 连接被拒很快，但留足超时
        let degraded = webText(containing: "列表加载失败")
        XCTAssertTrue(degraded.waitForExistence(timeout: 20),
                      "断 Sniper 应显示降级失败卡（可能白屏/未降级）")
        // 事件订阅区与列表区共存 = 整页未白屏（重试 button 不暴露 AX，不单独断言）
        XCTAssertTrue(webText(containing: "事件流").waitForExistence(timeout: 5),
                      "降级态下事件订阅区未渲染")
    }
}
