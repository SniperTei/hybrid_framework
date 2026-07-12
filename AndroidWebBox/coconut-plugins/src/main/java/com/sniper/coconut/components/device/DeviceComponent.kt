package com.sniper.coconut.components.device

import android.os.Build
import com.sniper.coconut.component.BaseComponent
import com.sniper.coconut.component.ComponentMetadata
import com.sniper.coconut.utils.Logger
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Device Component
 *
 * Provides device information and system properties
 */
@ComponentMetadata(
    name = "device",
    version = "1.0.0",
    description = "Device and system information component",
    dependencies = []
)
class DeviceComponent : BaseComponent() {

    override val name = "device"
    override val version = "1.0.0"
    override val description = "Device and system information component"

    override suspend fun handle(function: String, params: JsonObject?): JsonElement {
        return when (function) {
            "getInfo" -> getDeviceInfo()
            "getSystemInfo" -> getSystemInfo()
            "getAppInfo" -> getAppInfo()
            "getAll" -> getAllInfo()
            else -> functionNotSupportedError(function)
        }
    }

    /**
     * Get device information
     * Returns the standard cross-platform field set.
     */
    private suspend fun getDeviceInfo(): JsonElement = withContext(Dispatchers.IO) {
        val (screenW, screenH) = screenResolution()
        buildJsonObject {
            put("manufacturer", JsonPrimitive(Build.MANUFACTURER))
            put("brand", JsonPrimitive(Build.BRAND))
            put("model", JsonPrimitive(Build.MODEL))
            put("osName", JsonPrimitive("Android"))
            put("osVersion", JsonPrimitive(Build.VERSION.RELEASE ?: ""))
            put("platform", JsonPrimitive("android"))
            if (screenW > 0) put("screenWidth", JsonPrimitive(screenW))
            if (screenH > 0) put("screenHeight", JsonPrimitive(screenH))
        }.let { success(it) }
    }

    /**
     * Get system information
     * Returns the standard cross-platform field set.
     */
    private suspend fun getSystemInfo(): JsonElement = withContext(Dispatchers.IO) {
        buildJsonObject {
            put("osName", JsonPrimitive("Android"))
            put("osVersion", JsonPrimitive(Build.VERSION.RELEASE ?: ""))
            put("sdkVersion", JsonPrimitive(Build.VERSION.SDK_INT.toString()))
            put("model", JsonPrimitive(Build.MODEL))
            put("localizedModel", JsonPrimitive(Build.MODEL))
        }.let { success(it) }
    }

    /**
     * Best-effort screen resolution from system resources.
     * Returns (0, 0) when unavailable.
     */
    private fun screenResolution(): Pair<Int, Int> {
        return try {
            val dm = android.content.res.Resources.getSystem().displayMetrics
            Pair(dm.widthPixels, dm.heightPixels)
        } catch (t: Throwable) {
            Pair(0, 0)
        }
    }

    /**
     * Get app information
     * Returns app name, version, build number
     * Note: This requires context, will be enhanced later
     */
    private suspend fun getAppInfo(): JsonElement {
        return buildJsonObject {
            put("appName", JsonPrimitive("CoconutSDK"))
            put("packageName", JsonPrimitive("com.sniper.coconut"))
            put("version", JsonPrimitive("1.0.0"))
            put("buildNumber", JsonPrimitive("1"))
            put("debug", JsonPrimitive(false))
        }.let { success(it) }
    }

    /**
     * Get all information at once
     * Combines device, system, and app info
     */
    private suspend fun getAllInfo(): JsonElement {
        val deviceInfo = getDeviceInfo()
        val systemInfo = getSystemInfo()
        val appInfo = getAppInfo()

        return buildJsonObject {
            put("device", deviceInfo)
            put("system", systemInfo)
            put("app", appInfo)
        }.let { success(it) }
    }

    protected override suspend fun onCleanup() {
        Logger.d(name, "Device component cleanup complete")
    }
}
