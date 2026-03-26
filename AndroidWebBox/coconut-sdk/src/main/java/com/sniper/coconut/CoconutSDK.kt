package com.sniper.coconut

import android.content.Context
import com.sniper.coconut.component.BaseComponent
import com.sniper.coconut.component.ComponentManager
import com.sniper.coconut.config.CoconutConfig
import com.sniper.coconut.resource.ResourceManager
import com.sniper.coconut.resource.ResourceManagerImpl
import com.sniper.coconut.utils.Logger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Coconut SDK Main Entry Point
 *
 * Usage:
 * ```kotlin
 * CoconutSDK.initialize(context)
 * CoconutSDK.configure {
 *     setDebugMode(true)
 *     setTimeout(30000)
 * }
 * CoconutSDK.registerComponent(DeviceComponent())
 * ```
 */
object CoconutSDK {

    private var applicationContext: Context? = null
    private var isInitialized = false
    private val config = CoconutConfig()

    // Coroutine scope for SDK operations
    private val sdkScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    /**
     * Initialize SDK
     *
     * @param context Application context
     */
    fun initialize(context: Context) {
        if (isInitialized) {
            Logger.w("CoconutSDK", "Already initialized")
            return
        }

        applicationContext = context.applicationContext
        ComponentManager.getInstance().apply {
            setApplicationContext(context.applicationContext)
            setCoroutineScope(sdkScope)
        }

        isInitialized = true
        Logger.i("CoconutSDK", "CoconutSDK v${getVersion()} initialized")
    }

    /**
     * Configure SDK
     *
     * @param block Configuration block
     */
    fun configure(block: CoconutConfig.() -> Unit) {
        checkInitialized()
        config.apply(block)
        config.apply()
        Logger.i("CoconutSDK", "CoconutSDK configured")
    }

    /**
     * Register a component
     *
     * @param component Component instance
     */
    suspend fun registerComponent(component: BaseComponent) {
        checkInitialized()
        ComponentManager.getInstance().register(component)
    }

    /**
     * Register multiple components
     *
     * @param components Vararg of component instances
     */
    suspend fun registerComponents(vararg components: BaseComponent) {
        checkInitialized()
        ComponentManager.getInstance().inject(*components)
    }

    /**
     * Auto-register built-in components
     *
     * Scans com.sniper.coconut.components package for @ComponentMetadata annotated classes
     */
    suspend fun autoRegisterComponents() {
        checkInitialized()
        ComponentManager.getInstance().autoRegister("com.sniper.coconut.components")
        Logger.i("CoconutSDK", "Auto-registered built-in components")
    }

    /**
     * Unregister a component
     *
     * @param componentName Component name
     */
    suspend fun unregisterComponent(componentName: String) {
        checkInitialized()
        ComponentManager.getInstance().unregister(componentName)
    }

    /**
     * Get component by name
     *
     * @param name Component name
     * @return Component instance or null
     */
    suspend fun getComponent(name: String): com.sniper.coconut.component.CoconutPlugin? {
        checkInitialized()
        return ComponentManager.getInstance().getComponent(name)
    }

    /**
     * Get all registered component names
     *
     * @return List of component names
     */
    suspend fun getRegisteredComponents(): List<String> {
        checkInitialized()
        return ComponentManager.getInstance().getRegisteredComponents()
    }

    /**
     * Get component info
     *
     * @param name Component name
     * @return Component info or null
     */
    suspend fun getComponentInfo(name: String): com.sniper.coconut.component.ComponentInfo? {
        checkInitialized()
        return ComponentManager.getInstance().getComponentInfo(name)
    }

    /**
     * Get all components info
     *
     * @return List of component info
     */
    suspend fun getAllComponentsInfo(): List<com.sniper.coconut.component.ComponentInfo> {
        checkInitialized()
        return ComponentManager.getInstance().getAllComponentsInfo()
    }

    /**
     * Get resource manager
     *
     * @return ResourceManager instance
     */
    fun getResourceManager(): ResourceManager {
        checkInitialized()
        return ResourceManagerImpl.getInstance()
    }

    /**
     * Get SDK version
     *
     * @return Version string
     */
    fun getVersion(): String {
        return "1.0.0"
    }

    /**
     * Check if SDK is initialized
     *
     * @return true if initialized
     */
    fun isInitialized(): Boolean {
        return isInitialized
    }

    /**
     * Get application context
     *
     * @return Application context
     */
    fun getContext(): Context {
        checkInitialized()
        return applicationContext!!
    }

    /**
     * Cleanup resources
     */
    suspend fun cleanup() {
        if (!isInitialized) return

        Logger.d("CoconutSDK", "Cleaning up CoconutSDK...")

        ComponentManager.getInstance().cleanup()
        applicationContext = null
        isInitialized = false

        Logger.i("CoconutSDK", "CoconutSDK cleaned up")
    }

    /**
     * Execute operation in SDK scope
     *
     * @param block Operation to execute
     */
    fun launch(block: suspend () -> Unit) {
        checkInitialized()
        sdkScope.launch {
            try {
                block()
            } catch (e: Exception) {
                Logger.e("CoconutSDK", "Error in SDK scope", e)
            }
        }
    }

    private fun checkInitialized() {
        check(isInitialized) { "CoconutSDK not initialized. Call initialize() first." }
    }
}
