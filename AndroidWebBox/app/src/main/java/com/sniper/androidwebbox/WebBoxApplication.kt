package com.sniper.androidwebbox

import android.app.Application
import com.sniper.coconut.CoconutSDK
import com.sniper.androidwebbox.components.device.DeviceComponent
import com.sniper.androidwebbox.components.dialog.DialogComponent
import com.sniper.androidwebbox.components.event.EventComponent
import com.sniper.androidwebbox.components.network.NetworkComponent
import com.sniper.androidwebbox.components.navigator.NavigatorComponent
import com.sniper.androidwebbox.components.storage.StorageComponent
import com.sniper.coconut.config.Environment
import com.sniper.coconut.nav.TemplateRegistry
import com.sniper.coconut.web.CoconutWebActivity
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
     * 启动期校验 assets/coconut_templates.json：类可解析 + 是 CoconutWebActivity 子类。
     * 注意：这里查不出 manifest 漏声明（反射能解析类，启动才崩）——模板 Activity 必须
     * 在 AndroidManifest.xml 声明，见 API_CONTRACT.md §4.6。
     */
    private fun validateTemplateRegistry() {
        try {
            val text = assets.open("coconut_templates.json").bufferedReader().use { it.readText() }
            val templates = TemplateRegistry.validate(
                TemplateRegistry.parse(text),
                classLoader,
                CoconutWebActivity::class.java,
            )
            Logger.i("WebBoxApplication", "✅ Template registry validated: ${templates.keys}")
        } catch (e: Exception) {
            Logger.e("WebBoxApplication", "❌ Template registry invalid: ${e.message}")
        }
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

        // 3. 启动期严格校验模板注册表（fail-fast：类可解析 + 是容器子类；坏条目明确日志）
        validateTemplateRegistry()

        // 4. 注册组件（在协程中进行）
        applicationScope.launch {
            try {
                CoconutSDK.registerComponents(
                    DeviceComponent(),      // 设备信息
                    StorageComponent(),     // 本地存储
                    EventComponent(),       // 事件订阅
                    DialogComponent(),      // 原生弹窗
                    NetworkComponent(),     // 网络请求 + 状态推送
                    NavigatorComponent()    // 容器导航（forward/back/backToTop/close）
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
