package com.sniper.hybrid.core

import android.content.Intent
import android.util.Log
import com.sniper.hybrid.plugin.HybridPlugin
import com.sniper.hybrid.plugin.PluginCallback
import com.sniper.hybrid.plugin.PluginContext
import com.sniper.hybrid.plugin.PluginCallbackImpl
import org.json.JSONObject

/**
 * 插件管理器
 * 负责管理所有插件的注册、调用和生命周期
 */
class PluginManager(private val jsBridge: JSBridge) {

    private val plugins = mutableMapOf<String, HybridPlugin>()
    private var pluginContext: PluginContext? = null

    /**
     * 初始化插件上下文
     */
    fun init(context: PluginContext) {
        this.pluginContext = context
    }

    /**
     * 注册插件
     */
    fun registerPlugin(plugin: HybridPlugin) {
        val name = plugin.pluginName()
        if (plugins.containsKey(name)) {
            Log.w("PluginManager", "Plugin $name already registered, will be replaced")
        }
        plugins[name] = plugin
        pluginContext?.let { plugin.onAttach(it) }
        Log.d("PluginManager", "Plugin $name registered successfully")
    }

    /**
     * 批量注册插件
     */
    fun registerPlugins(pluginList: List<HybridPlugin>) {
        pluginList.forEach { registerPlugin(it) }
    }

    /**
     * 注销插件
     */
    fun unregisterPlugin(pluginName: String) {
        plugins.remove(pluginName)?.onDetach()
        Log.d("PluginManager", "Plugin $pluginName unregistered")
    }

    /**
     * 注销所有插件
     */
    fun unregisterAll() {
        plugins.values.forEach { it.onDetach() }
        plugins.clear()
    }

    /**
     * 执行插件方法
     */
    fun exec(pluginName: String, action: String, params: JSONObject, callbackId: String) {
        val plugin = plugins[pluginName]
        if (plugin == null) {
            Log.e("PluginManager", "Plugin not found: $pluginName")
            jsBridge.callJs(
                callbackId,
                false,
                null,
                null,
                "PLUGIN_NOT_FOUND" to "Plugin '$pluginName' not found"
            )
            return
        }

        val callback = PluginCallbackImpl(callbackId, jsBridge)

        try {
            plugin.exec(action, params, callback)
        } catch (e: Exception) {
            Log.e("PluginManager", "Error executing plugin action", e)
            callback.error("EXEC_ERROR", e.message)
        }
    }

    /**
     * 分发Activity结果
     */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        plugins.values.forEach { plugin ->
            try {
                if (plugin.onActivityResult(requestCode, resultCode, data)) {
                    Log.d("PluginManager", "Activity result handled by ${plugin.pluginName()}")
                    return@forEach
                }
            } catch (e: Exception) {
                Log.e("PluginManager", "Error in onActivityResult for ${plugin.pluginName()}", e)
            }
        }
    }

    /**
     * 分发权限结果
     */
    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        plugins.values.forEach { plugin ->
            try {
                if (plugin.onRequestPermissionsResult(requestCode, permissions, grantResults)) {
                    Log.d("PluginManager", "Permission result handled by ${plugin.pluginName()}")
                    return@forEach
                }
            } catch (e: Exception) {
                Log.e("PluginManager", "Error in onRequestPermissionsResult for ${plugin.pluginName()}", e)
            }
        }
    }

    /**
     * 获取所有已注册的插件
     */
    fun getRegisteredPlugins(): List<String> {
        return plugins.keys.toList()
    }

    /**
     * 检查插件是否已注册
     */
    fun isPluginRegistered(pluginName: String): Boolean {
        return plugins.containsKey(pluginName)
    }
}
