package com.sniper.hybrid.plugin

import android.content.Intent
import android.util.Log
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import org.json.JSONObject

/**
 * 插件基类，提供通用功能
 */
abstract class BasePlugin : HybridPlugin, DefaultLifecycleObserver {

    protected var pluginContext: PluginContext? = null
    protected var isAttached = false

    override fun onAttach(context: PluginContext) {
        this.pluginContext = context
        this.isAttached = true

        // 注册为生命周期观察者
        context.getLifecycle()?.addObserver(this)
    }

    override fun onDetach() {
        isAttached = false
        pluginContext = null
    }

    /**
     * 检查插件是否已附加
     */
    protected fun ensureAttached(): Boolean {
        if (!isAttached || pluginContext == null) {
            Log.w(pluginName(), "Plugin not attached")
            return false
        }
        return true
    }

    /**
     * 获取Context，null检查后返回
     */
    protected fun requireContext(): PluginContext {
        return pluginContext ?: throw IllegalStateException("Plugin not attached")
    }

    /**
     * 从JSONObject中安全获取参数
     */
    protected fun optString(params: JSONObject, key: String, default: String = ""): String {
        return params.optString(key, default)
    }

    protected fun optInt(params: JSONObject, key: String, default: Int = 0): Int {
        return params.optInt(key, default)
    }

    protected fun optBoolean(params: JSONObject, key: String, default: Boolean = false): Boolean {
        return params.optBoolean(key, default)
    }

    protected fun optDouble(params: JSONObject, key: String, default: Double = 0.0): Double {
        return params.optDouble(key, default)
    }

    /**
     * 子类重写此方法提供具体实现
     */
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        return false
    }

    /**
     * 子类重写此方法处理权限结果
     */
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        return false
    }
}
