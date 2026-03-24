package com.sniper.hybrid.plugin

import org.json.JSONObject

/**
 * 插件回调接口
 */
interface PluginCallback {
    /**
     * 成功回调
     * @param data 返回数据，可以是Map、List、String等
     */
    fun success(data: Any? = null)

    /**
     * 进度回调（用于有进度的操作，如文件上传）
     * @param progress 进度值 0-100
     */
    fun progress(progress: Int)

    /**
     * 错误回调
     * @param code 错误码
     * @param message 错误信息
     */
    fun error(code: String = "ERROR", message: String? = null)

    /**
     * 无操作回调
     */
    fun noOp()
}

/**
 * 插件回调实现
 */
class PluginCallbackImpl(
    private val callbackId: String,
    private val bridge: com.sniper.hybrid.core.JSBridge
) : PluginCallback {

    override fun success(data: Any?) {
        val result = when (data) {
            is JSONObject -> data.toString()
            is Map<*, *> -> JSONObject(data as Map<*, *>).toString()
            is List<*> -> org.json.JSONArray(data).toString()
            is String, is Number, is Boolean -> data
            null -> null
            else -> JSONObject(mapOf("data" to data)).toString()
        }
        bridge.callJs(callbackId, true, result, null, null)
    }

    override fun progress(progress: Int) {
        bridge.callJs(callbackId, null, null, progress, null)
    }

    override fun error(code: String, message: String?) {
        bridge.callJs(callbackId, false, null, null, code to (message ?: code))
    }

    override fun noOp() {
        // 不做任何操作
    }
}
