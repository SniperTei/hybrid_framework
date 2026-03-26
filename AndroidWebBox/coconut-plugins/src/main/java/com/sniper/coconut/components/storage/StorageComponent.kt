package com.sniper.coconut.components.storage

import android.content.Context
import android.content.SharedPreferences
import com.sniper.coconut.component.BaseComponent
import com.sniper.coconut.component.ComponentContext
import com.sniper.coconut.component.ComponentMetadata
import com.sniper.coconut.utils.Logger
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Storage Component
 *
 * Provides persistent storage capabilities
 */
@ComponentMetadata(
    name = "storage",
    version = "1.0.0",
    description = "Persistent storage component",
    dependencies = []
)
class StorageComponent : BaseComponent() {

    override val name = "storage"
    override val version = "1.0.0"
    override val description = "Persistent storage component"

    private var context: Context? = null
    private val preferences: SharedPreferences?
        get() = context?.getSharedPreferences("CoconutStorage", Context.MODE_PRIVATE)

    override suspend fun handle(function: String, params: JsonObject?): JsonElement {
        return when (function) {
            "setItem" -> setItem(params)
            "getItem" -> getItem(params)
            "removeItem" -> removeItem(params)
            "clear" -> clear()
            "getAllKeys" -> getAllKeys()
            "getSize" -> getSize()
            else -> functionNotSupportedError(function)
        }
    }

    protected override suspend fun onInit(context: ComponentContext) {
        this.context = context.applicationContext
        Logger.d(name, "Storage component initialized with context")
    }

    /**
     * Set item
     */
    private suspend fun setItem(params: JsonObject?): JsonElement {
        val key = getParam(params, "key")
        val value = getParam(params, "value")

        if (key.isEmpty()) {
            return error("900001", "Key cannot be empty")
        }

        preferences?.edit()?.putString(key, value)?.apply()
        Logger.d(name, "Set item: $key")

        return buildJsonObject {
            put("success", JsonPrimitive(true))
        }.let { success(it) }
    }

    /**
     * Get item
     */
    private suspend fun getItem(params: JsonObject?): JsonElement {
        val key = getParam(params, "key")

        if (key.isEmpty()) {
            return error("900001", "Key cannot be empty")
        }

        val value = preferences?.getString(key, null)
        Logger.d(name, "Get item: $key = $value")

        return buildJsonObject {
            put("value", JsonPrimitive(value ?: ""))
            put("exists", JsonPrimitive(value != null))
        }.let { success(it) }
    }

    /**
     * Remove item
     */
    private suspend fun removeItem(params: JsonObject?): JsonElement {
        val key = getParam(params, "key")

        if (key.isEmpty()) {
            return error("900001", "Key cannot be empty")
        }

        preferences?.edit()?.remove(key)?.apply()
        Logger.d(name, "Remove item: $key")

        return buildJsonObject {
            put("success", JsonPrimitive(true))
        }.let { success(it) }
    }

    /**
     * Clear all items
     */
    private suspend fun clear(): JsonElement {
        preferences?.edit()?.clear()?.apply()
        Logger.d(name, "Clear all items")

        return buildJsonObject {
            put("success", JsonPrimitive(true))
        }.let { success(it) }
    }

    /**
     * Get all keys
     */
    private suspend fun getAllKeys(): JsonElement {
        val keys = preferences?.all?.keys ?: emptySet<String>()

        return buildJsonObject {
            put("keys", kotlinx.serialization.json.buildJsonArray {
                keys.forEach { add(JsonPrimitive(it)) }
            })
            put("count", JsonPrimitive(keys.size))
        }.let { success(it) }
    }

    /**
     * Get storage size (approximate)
     */
    private suspend fun getSize(): JsonElement {
        val count = preferences?.all?.size ?: 0

        return buildJsonObject {
            put("count", JsonPrimitive(count))
            put("size", JsonPrimitive(count * 100)) // Approximate size in bytes
        }.let { success(it) }
    }

    protected override suspend fun onCleanup() {
        context = null
        Logger.d(name, "Storage component cleanup complete")
    }
}
