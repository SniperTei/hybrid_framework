package com.sniper.coconutandroidapp

import android.content.Context
import android.os.Build
import android.content.pm.PackageManager
import com.sniper.coconut.component.BaseComponent
import com.sniper.coconut.component.ComponentContext
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * 消费者自定义组件示例：设备信息（对齐 API_CONTRACT.md §4.1 的 device 字段集）。
 *
 * 只实现 getInfo / getSystemInfo / getAppInfo 三个方法 —— methods 数组必须
 * 与 handle() 的 switch 分支一致，coconut.supports() 据此向 H5 透出能力。
 */
class DeviceComponent : BaseComponent() {

    override val name = "device"
    override val version = "1.0.0"
    override val description = "Minimal device info component (consumer app sample)"
    override val methods = listOf("getInfo", "getSystemInfo", "getAppInfo")

    private var appContext: Context? = null

    override suspend fun onInit(context: ComponentContext) {
        appContext = context.applicationContext
    }

    override suspend fun handle(function: String, params: JsonObject?): JsonElement {
        return when (function) {
            "getInfo" -> getInfo()
            "getSystemInfo" -> getSystemInfo()
            "getAppInfo" -> getAppInfo()
            else -> functionNotSupportedError(function)
        }
    }

    private fun getInfo(): JsonElement {
        val (screenW, screenH) = screenResolution()
        return success(buildJsonObject {
            put("manufacturer", JsonPrimitive(Build.MANUFACTURER))
            put("brand", JsonPrimitive(Build.BRAND))
            put("model", JsonPrimitive(Build.MODEL))
            put("osName", JsonPrimitive("Android"))
            put("osVersion", JsonPrimitive(Build.VERSION.RELEASE ?: ""))
            put("platform", JsonPrimitive("android"))
            if (screenW > 0) put("screenWidth", JsonPrimitive(screenW))
            if (screenH > 0) put("screenHeight", JsonPrimitive(screenH))
        })
    }

    private fun getSystemInfo(): JsonElement {
        return success(buildJsonObject {
            put("osName", JsonPrimitive("Android"))
            put("osVersion", JsonPrimitive(Build.VERSION.RELEASE ?: ""))
            put("sdkVersion", JsonPrimitive(Build.VERSION.SDK_INT.toString()))
            put("model", JsonPrimitive(Build.MODEL))
            put("localizedModel", JsonPrimitive(Build.MODEL))
        })
    }

    private fun getAppInfo(): JsonElement {
        val ctx = appContext
        val pkgName = ctx?.packageName ?: "unknown"
        val versionName = try {
            ctx?.packageManager?.getPackageInfo(pkgName, 0)?.versionName ?: "1.0"
        } catch (_: PackageManager.NameNotFoundException) {
            "1.0"
        }
        return success(buildJsonObject {
            put("appName", JsonPrimitive("CoconutAndroidApp"))
            put("packageName", JsonPrimitive(pkgName))
            put("version", JsonPrimitive(versionName))
            put("buildNumber", JsonPrimitive("1"))
            val debuggable = ctx?.applicationInfo?.flags?.and(android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) ?: 0
            put("debug", JsonPrimitive(debuggable != 0))
        })
    }

    private fun screenResolution(): Pair<Int, Int> = try {
        val dm = android.content.res.Resources.getSystem().displayMetrics
        Pair(dm.widthPixels, dm.heightPixels)
    } catch (_: Throwable) {
        Pair(0, 0)
    }
}
