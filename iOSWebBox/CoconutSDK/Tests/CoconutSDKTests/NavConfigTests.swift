import XCTest
@testable import CoconutSDK

/// NavConfig merge/parse semantics — aligned with Android NavConfigTest.
final class NavConfigTests: XCTestCase {

    // ---- defaults ----

    func testDefaultIsVisibleWithAutoTitleAndAutoClosePolicy() {
        let d = NavConfig.default()
        XCTAssertEqual(true, d.visible)
        XCTAssertEqual(.auto, d.titleMode)
        XCTAssertEqual(.auto, d.closePolicy)
        XCTAssertNil(d.leftButtonText)
        XCTAssertNil(d.rightButtonText)
    }

    // ---- merge: nil = inherit, non-nil = override, per field ----

    func testMergeKeepsBaseFieldsWhenOverrideIsAllNil() {
        var base = NavConfig.default()
        base.titleMode = .fixed("基座")
        base.leftButtonText = "取消"
        let merged = NavConfig.merge(base: base, override: NavConfig())
        XCTAssertEqual(true, merged.visible)
        XCTAssertEqual(.fixed("基座"), merged.titleMode)
        XCTAssertEqual("取消", merged.leftButtonText)
    }

    func testMergeOverridesOnlyTheFieldsSet() {
        var base = NavConfig.default()
        base.titleMode = .fixed("旧标题")
        base.rightButtonText = "旧按钮"
        var override = NavConfig()
        override.visible = false
        let merged = NavConfig.merge(base: base, override: override)
        XCTAssertEqual(false, merged.visible)
        XCTAssertEqual(.fixed("旧标题"), merged.titleMode)
        XCTAssertEqual("旧按钮", merged.rightButtonText)
    }

    func testMergeDoesNotAliasInputInstances() {
        var base = NavConfig.default()
        var override = NavConfig()
        override.visible = false
        let merged = NavConfig.merge(base: base, override: override)
        override.visible = true
        XCTAssertEqual(false, merged.visible)
    }

    func testMergeChainGlobalThenTemplateThenHeaderResolvesPerField() {
        var global = NavConfig.default()
        global.rightButtonText = "全局分享"
        var template = NavConfig()
        template.titleMode = .fixed("模板页")
        var header = NavConfig()
        header.visible = false
        header.titleMode = .fixed("H5 标题")
        let merged = NavConfig.merge(base: NavConfig.merge(base: global, override: template), override: header)
        XCTAssertEqual(false, merged.visible)                 // header wins
        XCTAssertEqual(.fixed("H5 标题"), merged.titleMode)   // header wins
        XCTAssertEqual("全局分享", merged.rightButtonText)     // global wins
    }

    // ---- shouldShowClose truth table ----

    func testClosePolicyAutoShowsCloseOnlyAtStackRoot() {
        var cfg = NavConfig()
        cfg.closePolicy = .auto
        XCTAssertTrue(cfg.shouldShowClose(canGoBack: false))
        XCTAssertFalse(cfg.shouldShowClose(canGoBack: true))
    }

    func testClosePolicyAlwaysShowsCloseRegardlessOfHistory() {
        var cfg = NavConfig()
        cfg.closePolicy = .always
        XCTAssertTrue(cfg.shouldShowClose(canGoBack: false))
        XCTAssertTrue(cfg.shouldShowClose(canGoBack: true))
    }

    func testUnresolvedClosePolicyFallsBackToAutoSemantics() {
        let cfg = NavConfig()
        XCTAssertTrue(cfg.shouldShowClose(canGoBack: false))
        XCTAssertFalse(cfg.shouldShowClose(canGoBack: true))
    }

    // ---- parseOverride ----

    func testParseOverrideReadsAllFields() {
        let cfg = NavConfig.parseOverride(
            """
            {"visible":false,"title":"订单详情","closePolicy":"always",
             "leftButtonText":"取消","rightButtonText":"分享"}
            """
        )
        XCTAssertNotNil(cfg)
        XCTAssertEqual(false, cfg?.visible)
        XCTAssertEqual(.fixed("订单详情"), cfg?.titleMode)
        XCTAssertEqual(.always, cfg?.closePolicy)
        XCTAssertEqual("取消", cfg?.leftButtonText)
        XCTAssertEqual("分享", cfg?.rightButtonText)
    }

    func testParseOverrideTitleAutoMapsToAutoMode() {
        let cfg = NavConfig.parseOverride(#"{"title":"auto"}"#)
        XCTAssertEqual(.auto, cfg?.titleMode)
    }

    func testParseOverrideClosePolicyAutoInherits() {
        let cfg = NavConfig.parseOverride(#"{"closePolicy":"auto"}"#)
        XCTAssertNil(cfg?.closePolicy)
    }

    func testParseOverrideEmptyObjectYieldsAllNilOverride() {
        let cfg = NavConfig.parseOverride("{}")
        XCTAssertNotNil(cfg)
        XCTAssertNil(cfg?.visible)
        XCTAssertNil(cfg?.titleMode)
    }

    func testParseOverrideCaseInsensitive() {
        let cfg = NavConfig.parseOverride(#"{"title":"AUTO","closePolicy":"ALWAYS"}"#)
        XCTAssertEqual(.auto, cfg?.titleMode)
        XCTAssertEqual(.always, cfg?.closePolicy)
    }

    func testParseOverrideMalformedJsonReturnsNil() {
        XCTAssertNil(NavConfig.parseOverride("{not json"))
        XCTAssertNil(NavConfig.parseOverride(""))
    }

    // ---- legacy caller mapping ----

    func testLegacyVisibleFalseWithFixedTitle() {
        var legacy = NavConfig()
        legacy.visible = false
        legacy.titleMode = .fixed("旧调用方")
        let merged = NavConfig.merge(base: NavConfig.default(), override: legacy)
        XCTAssertEqual(false, merged.visible)
        XCTAssertEqual(.fixed("旧调用方"), merged.titleMode)
    }

    func testLegacyVisibleOnlyKeepsAutoDefault() {
        var legacy = NavConfig()
        legacy.visible = true
        let merged = NavConfig.merge(base: NavConfig.default(), override: legacy)
        XCTAssertEqual(.auto, merged.titleMode)
    }
}
