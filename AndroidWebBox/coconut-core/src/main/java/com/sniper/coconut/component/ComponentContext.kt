package com.sniper.coconut.component

import android.content.Context
import android.webkit.WebView
import com.sniper.coconut.event.EventEmitter
import kotlinx.coroutines.CoroutineScope

/**
 * Component Context
 *
 * Provides components with access to system resources and services.
 * Created once during component registration and updated dynamically
 * with the current host (Activity) reference.
 */
class ComponentContext(
    val applicationContext: Context,
    val coroutineScope: CoroutineScope
) {

    /**
     * Shared EventEmitter for native → H5 push.
     * Initialized by ComponentManager alongside this context.
     */
    @Volatile
    lateinit var eventEmitter: EventEmitter
        internal set
    /**
     * SDK version string, set during SDK configuration
     */
    @Volatile
    var sdkVersion: String = "2.0.0"
        internal set

    /**
     * Current ComponentHost (set by CoconutWebActivity)
     * Components that need Activity-level features should check this for null
     */
    @Volatile
    var host: ComponentHost? = null
        internal set

    /**
     * Get current Activity from host
     * Convenience method for components
     */
    val currentActivity: android.app.Activity?
        get() = host?.getActivity()

    /**
     * Get current WebView from host
     */
    val currentWebView: WebView?
        get() = host?.getHostWebView()

    /**
     * Get component by name
     * Allows components to interact with each other
     */
    suspend fun getComponent(name: String): CoconutPlugin? {
        return ComponentManager.getInstance().getComponent(name)
    }

    /**
     * Call another component's function
     */
    suspend fun callComponent(
        componentName: String,
        function: String,
        params: Map<String, Any?> = emptyMap()
    ): kotlinx.serialization.json.JsonElement? {
        val component = getComponent(componentName) ?: return null
        return component.handle(function, kotlinx.serialization.json.JsonObject(params.mapValues {
            kotlinx.serialization.json.JsonPrimitive(it.value.toString())
        }))
    }
}
