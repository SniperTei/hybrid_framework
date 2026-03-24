import Foundation

/// 插件协议
/// 所有插件必须实现此协议
public protocol HybridPlugin: AnyObject {
    /// 插件上下文
    var pluginContext: PluginContext? { get set }

    /// 插件名称
    func pluginName() -> String

    /// 执行插件方法
    /// - Parameters:
    ///   - action: 方法名
    ///   - params: 参数
    ///   - callback: 回调
    func exec(action: String, params: [String: Any], callback: PluginCallback)

    /// 插件附加到PluginManager时调用
    func onAttach(context: PluginContext)

    /// 插件从PluginManager移除时调用
    func onDetach()

    /// 检查方法是否存在 (默认实现)
    func hasAction(_ action: String) -> Bool
}

public extension HybridPlugin {
    func hasAction(_ action: String) -> Bool {
        // 默认实现,子类可以重写
        return true
    }
}
