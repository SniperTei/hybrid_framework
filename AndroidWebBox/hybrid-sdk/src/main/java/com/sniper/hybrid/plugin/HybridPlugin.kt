package com.sniper.hybrid.plugin

import android.content.Intent
import org.json.JSONObject

/**
 * Hybrid插件接口
 * 所有插件必须实现此接口
 */
interface HybridPlugin {
    /**
     * 插件名称，必须唯一
     * 例如: "camera", "gallery", "device"
     */
    fun pluginName(): String

    /**
     * 执行插件方法
     * @param action 动作名称，例如 "capture", "pick"
     * @param params 参数JSON对象
     * @param callback 回调接口
     */
    fun exec(action: String, params: JSONObject, callback: PluginCallback)

    /**
     * 插件被附加时调用
     * @param context 插件上下文
     */
    fun onAttach(context: PluginContext) {}

    /**
     * 插件被分离时调用，清理资源
     */
    fun onDetach() {}

    /**
     * 处理Activity结果
     * @param requestCode 请求码
     * @param resultCode 结果码
     * @param data 数据Intent
     * @return 是否已处理
     */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        return false
    }

    /**
     * 处理权限结果
     * @param requestCode 请求码
     * @param permissions 权限列表
     * @param grantResults 授权结果
     * @return 是否已处理
     */
    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        return false
    }

    /**
     * 获取插件版本
     */
    fun version(): String = "1.0.0"
}
