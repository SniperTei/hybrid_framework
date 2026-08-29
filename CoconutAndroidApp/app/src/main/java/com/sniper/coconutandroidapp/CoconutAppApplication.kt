package com.sniper.coconutandroidapp

import android.app.Application
import com.sniper.coconut.CoconutSDK
import com.sniper.coconut.utils.Logger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * CoconutAndroidApp — 真实消费者视角的集成验证 app（artifact 来自 mavenLocal）。
 *
 * SDK 只含框架，组件由宿主自己实现并显式注册（三端统一模式）。
 * 本 app 自带一个最小 DeviceComponent 验证扩展模型。
 */
class CoconutAppApplication : Application() {

    private val applicationScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    override fun onCreate() {
        super.onCreate()

        CoconutSDK.initialize(this)

        CoconutSDK.configure {
            setDebugMode(true)
            setTimeout(30000)
            setEnableWebViewDebug(true)
        }

        applicationScope.launch {
            try {
                CoconutSDK.registerComponents(
                    DeviceComponent()
                )
                Logger.i("CoconutApp", "✅ Components registered: ${CoconutSDK.getRegisteredComponents()}")
            } catch (e: Exception) {
                Logger.e("CoconutApp", "❌ Failed to register components", e)
            }
        }
    }
}
