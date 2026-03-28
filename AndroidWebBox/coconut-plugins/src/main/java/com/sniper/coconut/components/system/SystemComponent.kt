package com.sniper.coconut.components.system

import com.sniper.coconut.component.BaseComponent
import com.sniper.coconut.component.ComponentContext
import com.sniper.coconut.component.ComponentManager
import com.sniper.coconut.component.ComponentMetadata
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * System Component
 *
 * Provides version and capability introspection for the SDK.
 *
 * H5 Usage:
 *   Coconut.call('system.getVersion', {}, callback)
 *   Coconut.call('system.getComponentVersion', { name: 'network' }, callback)
 *   Coconut.call('system.getAllComponents', {}, callback)
 *   Coconut.call('system.checkCapability', { method: 'network.request' }, callback)
 */
@ComponentMetadata(
    name = "system",
    version = "1.0.0",
    description = "SDK version and capability introspection"
)
class SystemComponent : BaseComponent() {

    override val name = "system"
    override val version = "1.0.0"
    override val description = "SDK version and capability introspection"

    private var componentContext: ComponentContext? = null

    override suspend fun onInit(ctx: ComponentContext) {
        componentContext = ctx
    }

    override suspend fun handle(function: String, params: JsonObject?): JsonElement {
        return when (function) {
            "getVersion" -> getVersion()
            "getComponentVersion" -> getComponentVersion(params)
            "getAllComponents" -> getAllComponents()
            "checkCapability" -> checkCapability(params)
            else -> functionNotSupportedError(function)
        }
    }

    private fun getVersion(): JsonElement {
        val version = componentContext?.sdkVersion ?: "1.0.0"
        return buildJsonObject {
            put("sdkVersion", JsonPrimitive(version))
            put("timestamp", JsonPrimitive(System.currentTimeMillis()))
        }.let { success(it) }
    }

    private suspend fun getComponentVersion(params: JsonObject?): JsonElement {
        val name = getParam(params, "name")
        if (name.isEmpty()) {
            return error("900002", "Parameter 'name' is required")
        }

        val info = ComponentManager.getInstance().getComponentInfo(name)
            ?: return error("900001", "Component not found: $name")

        return buildJsonObject {
            put("name", JsonPrimitive(info.name))
            put("version", JsonPrimitive(info.version))
            put("description", JsonPrimitive(info.description))
            put("initialized", JsonPrimitive(info.isInitialized))
        }.let { success(it) }
    }

    private suspend fun getAllComponents(): JsonElement {
        val components = ComponentManager.getInstance().getAllComponentsInfo()
        val list = components.map { info ->
            buildJsonObject {
                put("name", JsonPrimitive(info.name))
                put("version", JsonPrimitive(info.version))
                put("description", JsonPrimitive(info.description))
                put("initialized", JsonPrimitive(info.isInitialized))
            }
        }

        return buildJsonObject {
            put("count", JsonPrimitive(list.size))
            put("components", kotlinx.serialization.json.buildJsonArray { list.forEach { add(it) } })
        }.let { success(it) }
    }

    private suspend fun checkCapability(params: JsonObject?): JsonElement {
        val method = getParam(params, "method")
        if (method.isEmpty()) {
            return error("900002", "Parameter 'method' is required")
        }

        val componentName = method.substringBefore(".")
        val component = ComponentManager.getInstance().getComponent(componentName)

        return buildJsonObject {
            put("method", JsonPrimitive(method))
            put("available", JsonPrimitive(component != null))
            put("componentRegistered", JsonPrimitive(component != null))
            put("componentInitialized", JsonPrimitive(component?.isInitialized ?: false))
        }.let { success(it) }
    }

    override suspend fun onCleanup() {
        componentContext = null
    }
}
