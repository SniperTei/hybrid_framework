//
//  PluginManager.swift
//  iOSWebBox
//
//  Plugin registration and execution manager
//

import Foundation
import UIKit

public class PluginManager {
    private var plugins: [String: HybridPlugin] = [:]
    private weak var jsBridge: JSBridge?

    public init(jsBridge: JSBridge) {
        self.jsBridge = jsBridge
    }

    public func registerPlugin(_ plugin: HybridPlugin) {
        plugins[plugin.pluginName()] = plugin
    }

    public func registerPlugins(_ plugins: [HybridPlugin]) {
        plugins.forEach { registerPlugin($0) }
    }

    public func unregisterPlugin(pluginName: String) {
        let plugin = plugins.removeValue(forKey: pluginName)
        plugin?.onDetach()
    }

    public func unregisterAll() {
        plugins.values.forEach { $0.onDetach() }
        plugins.removeAll()
    }

    public func exec(pluginName: String, action: String, params: [String: Any], callbackId: String) {
        guard let plugin = plugins[pluginName] else {
            jsBridge?.callJs(callbackId: callbackId, success: false, data: nil, progress: nil, error: ("PLUGIN_NOT_FOUND", "Plugin '\(pluginName)' not found"))
            return
        }

        let callback = PluginCallbackImpl(callbackId: callbackId, jsBridge: jsBridge!)
        DispatchQueue.main.async {
            plugin.exec(action: action, params: params, callback: callback)
        }
    }

    public func getPlugin(_ pluginName: String) -> HybridPlugin? {
        plugins[pluginName]
    }
}
