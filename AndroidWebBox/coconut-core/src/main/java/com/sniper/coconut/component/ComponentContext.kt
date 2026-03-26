package com.sniper.coconut.component

import android.content.Context
import android.webkit.WebView
import kotlinx.coroutines.CoroutineScope

/**
 * Component Context
 *
 * Provides components with access to system resources and services
 */
class ComponentContext(
    val applicationContext: Context,
    val coroutineScope: CoroutineScope,
    val webView: WebView? = null
) {
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
