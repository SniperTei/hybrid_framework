package com.sniper.androidwebbox

import android.app.Application
import com.sniper.coconut.CoconutSDK
import com.sniper.androidwebbox.components.device.DeviceComponent
import com.sniper.androidwebbox.components.storage.StorageComponent
import com.sniper.coconut.config.Environment
import com.sniper.coconut.utils.Logger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * AndroidWebBox Application
 *
 * 在这里初始化 Coconut SDK，确保在整个应用生命周期内只初始化一次
 */
class WebBoxApplication : Application() {

    // 应用级别的协程作用域
    private val applicationScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    override fun onCreate() {
        super.onCreate()

        Logger.i("WebBoxApplication", "Application onCreate")

        // 初始化 Coconut SDK
        initializeCoconutSDK()
    }

    /**
     * 初始化 Coconut SDK
     * 在这里注册所有需要的组件
     */
    private fun initializeCoconutSDK() {
        Logger.i("WebBoxApplication", "Initializing Coconut SDK...")

        // 1. 初始化 SDK（必须先调用）
        CoconutSDK.initialize(this)

        // 2. 配置 SDK（可选）
        CoconutSDK.configure {
            setDebugMode(true)           // 启用调试日志
            setTimeout(30000)            // 设置超时时间
            setEnableWebViewDebug(true)  // 启用 WebView 调试
            setEnvironment(Environment.DEV)  // 设置环境
        }

        // 3. 注册组件（在协程中进行）
        applicationScope.launch {
            try {
                CoconutSDK.registerComponents(
                    DeviceComponent(),      // 设备信息
                    StorageComponent()      // 本地存储
                )

                val components = CoconutSDK.getRegisteredComponents()
                Logger.i("WebBoxApplication", "✅ Components registered: $components")

            } catch (e: Exception) {
                Logger.e("WebBoxApplication", "❌ Failed to register components", e)
            }
        }
    }

    override fun onTerminate() {
        super.onTerminate()
        Logger.i("WebBoxApplication", "Application onTerminate")

        // 清理 SDK 资源
        applicationScope.launch {
            try {
                CoconutSDK.cleanup()
                Logger.i("WebBoxApplication", "Coconut SDK cleaned up")
            } catch (e: Exception) {
                Logger.e("WebBoxApplication", "Error during cleanup", e)
            }
        }
    }

    override fun onLowMemory() {
        super.onLowMemory()
        Logger.w("WebBoxApplication", "System low on memory")
    }

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        Logger.w("WebBoxApplication", "Trim memory level: $level")
    }
}
