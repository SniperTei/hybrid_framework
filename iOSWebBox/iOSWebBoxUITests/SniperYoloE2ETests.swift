//
//  SniperYoloE2ETests.swift
//  iOSWebBoxUITests
//
//  Sniper YOLO API 冒烟 e2e：CoconutNetwork 引擎 Swift 直调（不走 bridge），
//  对真实服务跑 Run All 5 步。前置：SNIPER_API_BASE 指向的 sniper-yolo
//  服务在线（默认用 AndroidWebBox/local.properties 的 sniperApiBase）。
//

import XCTest
import Foundation

@MainActor
final class SniperYoloE2ETests: XCTestCase {

    /// 真实服务地址：与 Android BuildConfig.SNIPER_API_BASE 同源
    /// （AndroidWebBox/local.properties 的 sniperApiBase，本地文件不入库）
    private let apiBase = "http://115.191.30.167:8041/api/v1"

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["SNIPER_API_BASE"] = apiBase
    }

    /// 日志区文本（UITextView value）
    private var logText: String {
        (app.textViews["sniper_log"].value as? String) ?? ""
    }

    /// 轮询日志区直到出现 marker（UITextView value 刷新非事件驱动，轮询比 waitForExistence 稳）
    private func waitForLog(_ marker: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if logText.contains(marker) { return true }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return logText.contains(marker)
    }

    private func openSmokePage() {
        app.launch()
        let entryBtn = app.buttons["Sniper API 冒烟 (native)"]
        XCTAssertTrue(entryBtn.waitForExistence(timeout: 15), "Home 入口按钮未出现")
        entryBtn.tap()
        let runAllBtn = app.buttons["Run All (5 步)"]
        XCTAssertTrue(runAllBtn.waitForExistence(timeout: 10), "冒烟页未加载")
    }

    func test01_RunAllAgainstRealService() {
        openSmokePage()

        // base URL 应被 env 钩子注入（防手滑打到默认 127.0.0.1）
        let baseField = app.textFields["sniper_base_url"]
        XCTAssertTrue(baseField.waitForExistence(timeout: 5), "base URL 输入框未出现")
        let baseValue = (baseField.value as? String) ?? ""
        XCTAssertTrue(baseValue.contains(apiBase), "SNIPER_API_BASE 未生效: \(baseValue)")

        app.buttons["Run All (5 步)"].tap()

        // 5 步全链路（每步 15s 超时上限 + 网络往返，给足余量）
        XCTAssertTrue(waitForLog("—— 全部 5 步完成 ——", timeout: 120),
                      "Run All 未完成。日志尾部:\n\(String(logText.suffix(1500)))")

        // 各步语义断言（Android 版同款 ✓ 标记）
        let log = logText
        XCTAssertTrue(log.contains("✓ token 已保存"), "第 1 步 login 未取到 access_token")
        XCTAssertTrue(log.contains("← HTTP 200"), "未见成功响应")
        XCTAssertTrue(log.contains("✓ 已记录新id="), "第 3 步 create 未取到新 id")
        XCTAssertTrue(log.contains("✓ 404 业务失败 envelope 正常"), "第 4 步 404 envelope 断言失败")
        XCTAssertTrue(log.contains("✓ 已清理 id="), "第 5 步 delete 清理失败")
        XCTAssertFalse(log.contains("✗"), "过程中出现 ✗ 失败标记:\n\(log)")
    }

    func test02_SingleStepLogin() {
        openSmokePage()
        app.buttons["1 登录 (test-login)"].tap()
        XCTAssertTrue(waitForLog("✓ token 已保存", timeout: 30),
                      "login 单步失败。日志:\n\(String(logText.suffix(800)))")
    }
}
