//
//  CoconutiOSAppUITests.swift
//  CoconutiOSAppUITests
//
//  Created by zhengnan on 2026/8/29.
//

import XCTest

/// 消费者冒烟：SPM 本地包接入 CoconutSDK 后，容器 + bridge 端到端可用。
/// WKWebView 的 DOM 按钮经 AX 树暴露为 buttons，pre 文本为 staticTexts。
final class CoconutiOSAppUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testContainerBridgeSmoke() throws {
        let app = XCUIApplication()
        app.launch()

        // 1. 打开容器（加载 bundle 里的 coconut_index.html）
        let openButton = app.buttons["打开 Coconut 容器"]
        XCTAssertTrue(openButton.waitForExistence(timeout: 10), "home 按钮未出现")
        openButton.tap()

        // 2. H5 已加载：设备组按钮可见
        let deviceButton = app.buttons["设备信息"].firstMatch
        XCTAssertTrue(deviceButton.waitForExistence(timeout: 15), "coconut_index.html 未加载")

        // 3. bridge round-trip：device.getInfo → 响应面板出现 Apple 字段
        deviceButton.tap()
        // 响应面板在页面底部，滚到可视区再查（WKWebView AX 对屏幕外文本可能不暴露）
        sleep(2)
        app.swipeUp()
        app.swipeUp()
        app.swipeUp()
        let resp = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Apple")
        ).firstMatch
        if !resp.waitForExistence(timeout: 10) {
            // 诊断：dump 可见 staticTexts
            for t in app.staticTexts.allElementsBoundByIndex.prefix(30) {
                print("[smoke] text: \(t.label.prefix(120))")
            }
            XCTFail("device.getInfo 响应未出现")
        }

        // 4. 完整信息（getAll）：迁入完整参考组件后已声明并处理 → 成功信封
        //    （旧最小消费者组件不声明 getAll → 200002；组件集已升级，断言随之翻转）
        app.buttons["完整信息"].firstMatch.tap()
        let all = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "packageName")
        ).firstMatch
        XCTAssertTrue(all.waitForExistence(timeout: 10), "getAll 响应未出现")
    }

    /// H5 App 入口：coconut://h5app/index.html 离线包（随 CoconutSDK SPM
    /// Resources 分发）经 SDK 本地服务加载，4 tab 壳渲染即算通。
    @MainActor
    func testH5AppEntry() throws {
        let app = XCUIApplication()
        app.launch()

        let h5AppButton = app.buttons["H5 App (4 tab)"]
        XCTAssertTrue(h5AppButton.waitForExistence(timeout: 10), "H5 App 按钮未出现")
        h5AppButton.tap()

        // tab 栏 4 项（<a> 内 span 文本 → staticTexts）；等首页内容就绪
        for title in ["首页", "发现", "AI", "我的"] {
            let tab = app.staticTexts[title].firstMatch
            XCTAssertTrue(tab.waitForExistence(timeout: 15), "tab「\(title)」未出现（h5app 离线包未加载？）")
        }
    }
}
