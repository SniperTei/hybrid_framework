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

        // 4. 未声明方法（getAll 不在消费者组件 methods 数组）→ 200002 错误信封
        app.buttons["完整信息"].firstMatch.tap()
        let err = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "200002")
        ).firstMatch
        XCTAssertTrue(err.waitForExistence(timeout: 10), "getAll 应返回 200002 错误信封")
    }
}
