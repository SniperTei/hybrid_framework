import Foundation
import CoconutSDK

/**
 * Update Component — H5 热更新入口（app 层第 7 个组件）· iOS 空实现.

 * 同契约不同实现的首个正式案例（API_CONTRACT.md §4.7）：方法照常声明
 * （capabilities 注入 → H5 `coconut.supports('update','check')` 为 true，
 * 语义是「方法在但平台不支持」），但每个方法返回业务层失败
 * （code 000000 + success:false）——不走 bridge error 200003，对齐
 * 「权限/平台拒绝走业务层」的既有约定。
 *
 * 原因：App Store 审核约束（App Review Guideline 2.5.2 —— 禁止下载
 * 可执行代码改变应用行为）。iOS 侧热更新由 WKWebView 离线包 + App
 * 发版承载；H5 可用 coconut.env.isIOS 直接置灰入口。
 */
public class UpdateComponent: BaseComponent {
    override public init() { super.init() }

    override public var name: String { "update" }
    override public var version: String { "1.0.0" }
    override public var pluginDescription: String { "Hot update component (check/apply/rollback/version) — iOS stub (App Store 2.5.2)" }
    override public var methods: [String] { ["check", "apply", "rollback", "version"] }

    override public func handle(function: String, params: [String: Any]?) async throws -> [String: Any] {
        switch function {
        case "check", "apply", "rollback", "version":
            return businessFailure("\(function) is not supported on iOS — App Store Review Guideline 2.5.2 forbids downloading executable code")
        default:
            try functionNotSupportedError(function)
        }
    }

    private func businessFailure(_ message: String) -> [String: Any] {
        success([
            "success": false,
            "message": message
        ])
    }
}
