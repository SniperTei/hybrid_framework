package com.sniper.coconut.component

import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject

/**
 * Coconut Component Interface
 *
 * All components must implement this interface
 * Provides component lifecycle management and function handling
 */
interface CoconutPlugin {

    /**
     * Component name (unique identifier)
     * Used in routing: "componentName.function"
     */
    val name: String

    /**
     * Component version
     * Format: "major.minor.patch"
     */
    val version: String

    /**
     * Component description
     */
    val description: String
        get() = ""

    /**
     * Component dependencies
     * List of component names that this component depends on
     */
    val dependencies: List<String>
        get() = emptyList()

    /**
     * Initialize component
     * Called when component is registered
     *
     * @param context Component context with access to system resources
     */
    suspend fun init(context: ComponentContext)

    /**
     * Handle function call
     *
     * @param function Function name (without component prefix)
     * @param params Parameters as JsonObject
     * @return Result as JsonElement
     */
    suspend fun handle(function: String, params: JsonObject?): JsonElement

    /**
     * Check if component is initialized
     */
    val isInitialized: Boolean

    /**
     * Cleanup component resources
     * Called when component is unregistered or app is destroyed
     */
    suspend fun cleanup()
}
