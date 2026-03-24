import Foundation
import UIKit

/// 插件管理器
/// 负责插件的注册、调用和生命周期管理
public class PluginManager {
    private var plugins: [String: HybridPlugin] = [:]
    private weak var jsBridge: JSBridge?
    private var pluginContext: PluginContext?

    public init(jsBridge: JSBridge) {
        self.jsBridge = jsBridge
    }

    /// 初始化
    public func init(viewController: UIViewController) {
        self.pluginContext = PluginContext(viewController: viewController)
    }

    /// 获取PluginContext
    public func getPluginContext() -> PluginContext? {
        return pluginContext
    }

    /// 注册单个插件
    public func registerPlugin(_ plugin: HybridPlugin) {
        let name = plugin.pluginName()
        plugins[name] = plugin
        if let context = pluginContext {
            plugin.onAttach(context: context)
        }
    }

    /// 批量注册插件
    public func registerPlugins(_ plugins: [HybridPlugin]) {
        for plugin in plugins {
            registerPlugin(plugin)
        }
    }

    /// 注销插件
    public func unregisterPlugin(pluginName: String) {
        if let plugin = plugins.removeValue(forKey: pluginName) {
            plugin.onDetach()
        }
    }

    /// 注销所有插件
    public func unregisterAll() {
        for (_, plugin) in plugins {
            plugin.onDetach()
        }
        plugins.removeAll()
    }

    /// 获取插件
    public func getPlugin(pluginName: String) -> HybridPlugin? {
        return plugins[pluginName]
    }

    /// 检查插件是否存在
    public func hasPlugin(pluginName: String) -> Bool {
        return plugins[pluginName] != nil
    }

    /// 执行插件方法
    public func exec(pluginName: String, action: String, params: [String: Any], callbackId: String) {
        guard let plugin = plugins[pluginName] else {
            jsBridge?.callJs(
                callbackId: callbackId,
                success: false,
                data: nil,
                progress: nil,
                error: ("PLUGIN_NOT_FOUND", "Plugin '\(pluginName)' not found")
            )
            return
        }

        let callback = PluginCallbackImpl(jsBridge: jsBridge!, callbackId: callbackId)

        pluginContext?.runOnMainThread {
            plugin.exec(action: action, params: params, callback: callback)
        }
    }
}
