//
//  SettingsE2ETests.swift
//  iOSWebBoxUITests
//
//  真实业务试点 Phase 3 e2e：native 首页「设置页」按钮 → 离线包 hash 路由
//  #/settings（coconut:// scheme）→ 设置页渲染 / update 组件 iOS 空实现
//  业务层失败语义（App Store 2.5.2）/ 偏好开关 + 保存并关闭回传。
//  离线包随 CoconutSDK SPM resources 打包，无需 dev server。
//

import XCTest
import Foundation

@MainActor
final class SettingsE2ETests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func webButton(_ label: String) -> XCUIElement {
        app.webViews.buttons[label]
    }

    private func webText(containing text: String) -> XCUIElement {
        app.webViews.descendants(matching: .staticText)
            .matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// Home → 设置页（离线包 hash 路由）→ 等 H5 首屏
    private func openSettings() {
        app.launch()
        let btn = app.buttons["设置页 (#/settings)"]
        XCTAssertTrue(btn.waitForExistence(timeout: 15), "Home 设置页入口未出现")
        btn.tap()
        XCTAssertTrue(webText(containing: "检查更新").waitForExistence(timeout: 25),
                      "设置页未渲染（coconut:// + #/settings 路由失败？）")
        sleep(2)  // WebView 坐标稳定（ContainerNav test01 教训）
    }

    func test01_settingsRendersFromNativeEntry() {
        openSettings()
        XCTAssertTrue(webText(containing: "关于").exists)
        XCTAssertTrue(webText(containing: "存储管理").exists || webText(containing: "偏好").exists)
    }

    /// iOS update 组件 = 空实现：methods 照常声明（supports=true，显示检查 UI），
    /// 点检查更新 → 业务层失败 → 状态含 App Store 2.5.2 说明。
    func test02_updateStubBusinessFailure() {
        openSettings()
        webButton("检查更新").tap()
        let status = webText(containing: "不支持")
        XCTAssertTrue(status.waitForExistence(timeout: 15), "检查更新未返回业务层失败")
        let label = status.label
        XCTAssertTrue(label.contains("App Store") || label.contains("2.5.2"),
                      "失败信息应注明 App Store 2.5.2，实际：\(label)")
    }

    /// 偏好开关 → changed 计数 → 保存并关闭（navigator.close 回传）
    func test03_prefToggleAndClose() {
        openSettings()
        // 偏好在存储管理下方，滚动到偏好区
        app.swipeUp()
        // toggle 按钮内只有 knob（无文本 → 无 AX label），按「推送」标签
        // 文本行右侧坐标点击（开关固定在行尾）
        let prefLabel = webText(containing: "推送")
        if !prefLabel.waitForExistence(timeout: 5) {
            app.swipeUp()
            XCTAssertTrue(prefLabel.waitForExistence(timeout: 5), "偏好标签未找到")
        }
        let frame = prefLabel.frame
        let offset = CGVector(dx: app.frame.width - 44, dy: frame.midY)
        app.coordinate(withNormalizedOffset: .zero).withOffset(offset).tap()
        sleep(1)
        let closeBtn = app.webViews.buttons.matching(
            NSPredicate(format: "label CONTAINS '保存并关闭'")).firstMatch
        XCTAssertTrue(closeBtn.waitForExistence(timeout: 5), "保存并关闭按钮未找到")
        XCTAssertTrue(closeBtn.label.contains("回传"), "开关后应显示回传变更数，实际：\(closeBtn.label)")
        closeBtn.tap()
        // 容器关闭回到 Home
        XCTAssertTrue(app.buttons["设置页 (#/settings)"].waitForExistence(timeout: 10),
                      "close 后未回到 Home")
    }
}
