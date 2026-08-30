package com.sniper.coconutandroidapp

import android.app.Application
import com.sniper.coconut.CoconutSDK
import com.sniper.coconut.utils.Logger
import com.sniper.coconutandroidapp.components.device.DeviceComponent
import com.sniper.coconutandroidapp.components.dialog.DialogComponent
import com.sniper.coconutandroidapp.components.event.EventComponent
import com.sniper.coconutandroidapp.components.navigator.NavigatorComponent
import com.sniper.coconutandroidapp.components.network.NetworkComponent
import com.sniper.coconutandroidapp.components.storage.StorageComponent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * CoconutAndroidApp — 真实消费者视角的集成验证 app（artifact 来自 mavenLocal）。
 *
 * SDK 只含框架，组件由宿主自己实现并显式注册（三端统一模式）。
 * components/ 下是从 AndroidWebBox 拷入的通用参考组件
 * （device / storage / event / dialog / network / navigator），
 * 支撑 H5 App（coconutH5App，离线包模块 h5app）的完整功能；
 * update 组件按需装配，本 app 未引入（H5 设置页会正确显示「未注册」）。
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
                    DeviceComponent(),
                    StorageComponent(),
                    EventComponent(),
                    DialogComponent(),
                    NetworkComponent(),
                    NavigatorComponent(),
                )
                Logger.i("CoconutApp", "✅ Components registered: ${CoconutSDK.getRegisteredComponents()}")
            } catch (e: Exception) {
                Logger.e("CoconutApp", "❌ Failed to register components", e)
            }
        }
    }
}
