import Foundation
import UIKit

/// 插件上下文
/// 提供插件运行时所需的环境信息
public class PluginContext {
    /// UIViewController实例
    public let viewController: UIViewController

    /// 应用Context
    public let applicationContext: UIApplication

    /// 初始化
    public init(viewController: UIViewController) {
        self.viewController = viewController
        self.applicationContext = UIApplication.shared
    }

    /// 获取主ViewController
    public func getViewController() -> UIViewController {
        return viewController
    }

    /// 运行在主线程
    public func runOnMainThread(_ block: @escaping () -> Void) {
        DispatchQueue.main.async {
            block()
        }
    }

    /// 运行在后台线程
    public func runOnBackgroundThread(_ block: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            block()
        }
    }
}
