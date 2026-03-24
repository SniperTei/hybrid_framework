import Foundation

/// 插件基类
/// 提供通用的插件功能
open class BasePlugin: HybridPlugin {
    public weak var pluginContext: PluginContext?

    public init() {}

    /// 子类重写此方法实现插件名称
    open func pluginName() -> String {
        return "BasePlugin"
    }

    /// 子类重写此方法实现具体功能
    open func exec(action: String, params: [String: Any], callback: PluginCallback) {
        callback.error(code: "UNKNOWN_ACTION", message: "Unknown action: \(action)")
    }

    /// 插件附加
    public func onAttach(context: PluginContext) {
        self.pluginContext = context
    }

    /// 插件分离
    public func onDetach() {
        self.pluginContext = nil
    }

    // MARK: - 辅助方法

    /// 安全获取String参数
    public func optString(_ params: [String: Any], _ key: String, defaultValue: String? = nil) -> String? {
        if let value = params[key] {
            if let stringValue = value as? String {
                return stringValue
            } else if let numberValue = value as? NSNumber {
                return numberValue.stringValue
            }
        }
        return defaultValue
    }

    /// 安全获取Int参数
    public func optInt(_ params: [String: Any], _ key: String, defaultValue: Int? = nil) -> Int? {
        if let value = params[key] {
            if let intValue = value as? Int {
                return intValue
            } else if let numberValue = value as? NSNumber {
                return numberValue.intValue
            } else if let stringValue = value as? String, let intValue = Int(stringValue) {
                return intValue
            }
        }
        return defaultValue
    }

    /// 安全获取Bool参数
    public func optBool(_ params: [String: Any], _ key: String, defaultValue: Bool? = nil) -> Bool? {
        if let value = params[key] {
            if let boolValue = value as? Bool {
                return boolValue
            } else if let numberValue = value as? NSNumber {
                return numberValue.boolValue
            } else if let stringValue = value as? String {
                return stringValue.lowercased() == "true" || stringValue == "1"
            }
        }
        return defaultValue
    }

    /// 安全获取Double参数
    public func optDouble(_ params: [String: Any], _ key: String, defaultValue: Double? = nil) -> Double? {
        if let value = params[key] {
            if let doubleValue = value as? Double {
                return doubleValue
            } else if let numberValue = value as? NSNumber {
                return numberValue.doubleValue
            } else if let stringValue = value as? String, let doubleValue = Double(stringValue) {
                return doubleValue
            }
        }
        return defaultValue
    }

    /// 安全获取Dict参数
    public func optDict(_ params: [String: Any], _ key: String) -> [String: Any]? {
        return params[key] as? [String: Any]
    }

    /// 安全获取Array参数
    public func optArray(_ params: [String: Any], _ key: String) -> [Any]? {
        return params[key] as? [Any]
    }

    /// 获取ViewController
    public func getViewController() -> UIViewController? {
        return pluginContext?.getViewController()
    }

    /// 运行在主线程
    public func runOnMainThread(_ block: @escaping () -> Void) {
        pluginContext?.runOnMainThread(block)
    }

    /// 运行在后台线程
    public func runOnBackgroundThread(_ block: @escaping () -> Void) {
        pluginContext?.runOnBackgroundThread(block)
    }
}
