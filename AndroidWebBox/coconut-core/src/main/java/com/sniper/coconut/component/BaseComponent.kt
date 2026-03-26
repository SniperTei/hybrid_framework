package com.sniper.coconut.component

import com.sniper.coconut.utils.Logger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Base Component Class
 *
 * All components should extend this class
 * Provides common functionality and utilities
 */
abstract class BaseComponent : CoconutPlugin {

    protected val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private var _initialized = false

    final override val isInitialized: Boolean
        get() = _initialized

    final override suspend fun init(context: ComponentContext) {
        if (_initialized) {
            Logger.w(name, "Component already initialized")
            return
        }

        Logger.d(name, "Initializing component...")
        onInit(context)
        _initialized = true
        Logger.d(name, "✓ Component initialized")
    }

    /**
     * Called when component is being initialized
     * Override this method to perform component-specific initialization
     *
     * @param context Component context
     */
    protected open suspend fun onInit(context: ComponentContext) {
        // Override in subclasses if needed
    }

    final override suspend fun cleanup() {
        Logger.d(name, "Cleaning up component...")
        onCleanup()
        _initialized = false
        Logger.d(name, "✓ Component cleaned up")
    }

    /**
     * Called when component is being cleaned up
     * Override this method to perform component-specific cleanup
     */
    protected open suspend fun onCleanup() {
        // Override in subclasses if needed
    }

    /**
     * Get parameter value as string
     */
    protected fun getParam(params: JsonObject?, key: String, default: String = ""): String {
        return params?.get(key)?.let {
            when (it) {
                is JsonPrimitive -> if (it.isString) it.content else default
                else -> it.toString()
            }
        } ?: default
    }

    /**
     * Get parameter as int
     */
    protected fun getIntParam(params: JsonObject?, key: String, default: Int = 0): Int {
        return params?.get(key)?.let {
            when (it) {
                is JsonPrimitive -> if (it is JsonPrimitive) it.content.toIntOrNull() ?: default else default
                else -> default
            }
        } ?: default
    }

    /**
     * Get parameter as boolean
     */
    protected fun getBoolParam(params: JsonObject?, key: String, default: Boolean = false): Boolean {
        return params?.get(key)?.let {
            when (it) {
                is JsonPrimitive -> if (it is JsonPrimitive) it.content.toBooleanStrictOrNull() ?: default else default
                else -> default
            }
        } ?: default
    }

    /**
     * Build success result
     *
     * @param data Result data
     * @return JsonElement with success format
     */
    protected fun success(data: JsonElement? = null): JsonElement {
        return buildJsonObject {
            put("code", JsonPrimitive("000000"))
            put("message", JsonPrimitive("success"))
            data?.let { put("data", it) }
        }
    }

    /**
     * Build error result
     *
     * @param code Error code (string)
     * @param message Error message
     * @return JsonElement with error format
     */
    protected fun error(code: String, message: String): JsonElement {
        return buildJsonObject {
            put("code", JsonPrimitive(code))
            put("message", JsonPrimitive(message))
        }
    }

    /**
     * Build function not supported error
     */
    protected fun functionNotSupportedError(function: String): JsonElement {
        return error("900002", "Function not supported: $function")
    }
}
