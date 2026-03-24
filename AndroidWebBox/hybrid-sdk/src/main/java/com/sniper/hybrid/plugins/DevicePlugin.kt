package com.sniper.hybrid.plugins

import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.telephony.TelephonyManager
import android.util.DisplayMetrics
import android.view.WindowManager
import com.sniper.hybrid.plugin.BasePlugin
import com.sniper.hybrid.plugin.PluginCallback
import org.json.JSONObject
import java.io.File
import java.util.Locale

/**
 * 设备信息插件
 * 获取设备基本信息
 */
class DevicePlugin : BasePlugin() {

    override fun pluginName() = "device"

    override fun exec(action: String, params: JSONObject, callback: PluginCallback) {
        if (!ensureAttached()) {
            callback.error("PLUGIN_ERROR", "Plugin not attached")
            return
        }

        when (action) {
            "getInfo" -> getInfo(callback)
            "getSystemInfo" -> getSystemInfo(callback)
            else -> callback.error("UNKNOWN_ACTION", "Unknown action: $action")
        }
    }

    /**
     * 获取设备信息（简化版）
     */
    private fun getInfo(callback: PluginCallback) {
        val context = requireContext().getContext()
        val packageManager = context.packageManager
        val packageInfo = try {
            packageManager.getPackageInfo(context.packageName, 0)
        } catch (e: PackageManager.NameNotFoundException) {
            null
        }

        val info = mutableMapOf(
            // App信息
            "appId" to context.packageName,
            "appName" to context.applicationInfo.loadLabel(packageManager).toString(),
            "appVersion" to (packageInfo?.versionName ?: "unknown"),
            "appVersionCode" to (if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                packageInfo?.longVersionCode?.toString() ?: "unknown"
            } else {
                @Suppress("DEPRECATION")
                packageInfo?.versionCode?.toString() ?: "unknown"
            }),

            // 设备基本信息
            "platform" to "android",
            "system" to "Android",
            "systemVersion" to Build.VERSION.RELEASE,
            "sdkVersion" to Build.VERSION.SDK_INT,
            "model" to Build.MODEL,
            "brand" to Build.BRAND,
            "manufacturer" to Build.MANUFACTURER,
            "device" to Build.DEVICE,

            // 屏幕信息
            "screenWidth" to getScreenWidth(context),
            "screenHeight" to getScreenHeight(context),
            "screenDensity" to getScreenDensity(context),

            // 语言和地区
            "language" to Locale.getDefault().language,
            "country" to Locale.getDefault().country,

            // 网络状态
            "networkType" to getNetworkType(context)
        )

        callback.success(info)
    }

    /**
     * 获取系统信息（详细版）
     */
    private fun getSystemInfo(callback: PluginCallback) {
        val context = requireContext().getContext()

        val info = mutableMapOf(
            // 系统详细信息
            "platform" to "android",
            "system" to "Android",
            "systemVersion" to Build.VERSION.RELEASE,
            "sdkVersion" to Build.VERSION.SDK_INT,
            "buildId" to Build.ID,
            "buildTime" to Build.TIME,
            "buildType" to Build.TYPE,
            "buildUser" to Build.USER,

            // 设备详细信息
            "model" to Build.MODEL,
            "brand" to Build.BRAND,
            "manufacturer" to Build.MANUFACTURER,
            "device" to Build.DEVICE,
            "product" to Build.PRODUCT,
            "board" to Build.BOARD,
            "hardware" to Build.HARDWARE,
            "bootloader" to Build.BOOTLOADER,
            "fingerprint" to Build.FINGERPRINT,

            // CPU信息
            "cpuArch" to Build.SUPPORTED_ABIS.joinToString(","),

            // 屏幕详细信息
            "screenWidth" to getScreenWidth(context),
            "screenHeight" to getScreenHeight(context),
            "screenDensity" to getScreenDensity(context),
            "screenDensityDpi" to getScreenDensityDpi(context),

            // 内存信息（近似值）
            "totalMemory" to getTotalMemory(),
            "availableMemory" to getAvailableMemory(context),

            // 存储信息
            "totalStorage" to getTotalStorage(),
            "availableStorage" to getAvailableStorage(),

            // 语言和地区
            "language" to Locale.getDefault().language,
            "country" to Locale.getDefault().country,
            "timezone" to getTimeZone(),

            // 其他信息
            "uniqueId" to getUniqueId(context),
            "isEmulator" to isEmulator(),
            "isRoot" to isRooted()
        )

        callback.success(info)
    }

    /**
     * 获取屏幕宽度
     */
    private fun getScreenWidth(context: Context): Int {
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val metrics = DisplayMetrics()
        wm.defaultDisplay.getMetrics(metrics)
        return metrics.widthPixels
    }

    /**
     * 获取屏幕高度
     */
    private fun getScreenHeight(context: Context): Int {
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val metrics = DisplayMetrics()
        wm.defaultDisplay.getMetrics(metrics)
        return metrics.heightPixels
    }

    /**
     * 获取屏幕密度
     */
    private fun getScreenDensity(context: Context): Float {
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val metrics = DisplayMetrics()
        wm.defaultDisplay.getMetrics(metrics)
        return metrics.density
    }

    /**
     * 获取屏幕密度DPI
     */
    private fun getScreenDensityDpi(context: Context): Int {
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val metrics = DisplayMetrics()
        wm.defaultDisplay.getMetrics(metrics)
        return metrics.densityDpi
    }

    /**
     * 获取网络类型
     */
    private fun getNetworkType(context: Context): String {
        // 简化版，实际应该使用ConnectivityManager
        return "unknown"
    }

    /**
     * 获取总内存（MB）
     */
    private fun getTotalMemory(): Long {
        return try {
            val activityManager = requireContext().getContext()
                .getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
            val memInfo = android.app.ActivityManager.MemoryInfo()
            activityManager.getMemoryInfo(memInfo)
            memInfo.totalMem / (1024 * 1024)
        } catch (e: Exception) {
            0
        }
    }

    /**
     * 获取可用内存（MB）
     */
    private fun getAvailableMemory(context: Context): Long {
        return try {
            val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
            val memInfo = android.app.ActivityManager.MemoryInfo()
            activityManager.getMemoryInfo(memInfo)
            memInfo.availMem / (1024 * 1024)
        } catch (e: Exception) {
            0
        }
    }

    /**
     * 获取总存储空间（MB）
     */
    private fun getTotalStorage(): Long {
        return try {
            val stat = android.os.StatFs(android.os.Environment.getExternalStorageDirectory().path)
            stat.totalBytes / (1024 * 1024)
        } catch (e: Exception) {
            0
        }
    }

    /**
     * 获取可用存储空间（MB）
     */
    private fun getAvailableStorage(): Long {
        return try {
            val stat = android.os.StatFs(android.os.Environment.getExternalStorageDirectory().path)
            stat.availableBytes / (1024 * 1024)
        } catch (e: Exception) {
            0
        }
    }

    /**
     * 获取时区
     */
    private fun getTimeZone(): String {
        return java.util.TimeZone.getDefault().id
    }

    /**
     * 获取设备唯一ID
     */
    @SuppressLint("HardwareIds")
    private fun getUniqueId(context: Context): String {
        return try {
            Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ANDROID_ID
            )
        } catch (e: Exception) {
            "unknown"
        }
    }

    /**
     * 判断是否是模拟器
     */
    private fun isEmulator(): Boolean {
        return (Build.FINGERPRINT.startsWith("generic")
                || Build.FINGERPRINT.startsWith("unknown")
                || Build.MODEL.contains("google_sdk")
                || Build.MODEL.contains("Emulator")
                || Build.MODEL.contains("Android SDK built for x86")
                || Build.MANUFACTURER.contains("Genymotion")
                || (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic"))
                || "google_sdk" == Build.PRODUCT)
    }

    /**
     * 判断是否已Root
     */
    private fun isRooted(): Boolean {
        val rootPaths = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su",
            "/su/bin/su"
        )

        return rootPaths.any { File(it).exists() }
    }
}
