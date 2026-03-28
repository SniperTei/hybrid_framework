package com.sniper.coconut.resource

import com.sniper.coconut.component.BaseComponent
import com.sniper.coconut.component.ComponentContext
import com.sniper.coconut.component.ComponentMetadata
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Resource Component
 *
 * H5 calls this to manage offline resources and check for updates.
 *
 * Usage:
 *   Coconut.call('resource.getVersion', { moduleId: 'main' }, callback)
 *   Coconut.call('resource.getAllVersions', {}, callback)
 *   Coconut.call('resource.checkUpdate', { moduleId: 'main', remoteVersion: '1.0.1' }, callback)
 *   Coconut.call('resource.applyUpdate', { moduleId: 'main', version: '1.0.1', downloadUrl: '...', md5: '...' }, callback)
 */
@ComponentMetadata(
    name = "resource",
    version = "1.0.0",
    description = "Offline resource management and hot update component"
)
class ResourceComponent : BaseComponent() {

    override val name = "resource"
    override val version = "1.0.0"
    override val description = "Offline resource management and hot update component"

    private var componentContext: ComponentContext? = null

    override suspend fun onInit(ctx: ComponentContext) {
        componentContext = ctx
    }

    override suspend fun handle(function: String, params: JsonObject?): JsonElement {
        return when (function) {
            "getVersion" -> getVersion(params)
            "getAllVersions" -> getAllVersions()
            "checkUpdate" -> checkUpdate(params)
            "applyUpdate" -> applyUpdate(params)
            else -> functionNotSupportedError(function)
        }
    }

    private fun getVersion(params: JsonObject?): JsonElement {
        val moduleId = getParam(params, "moduleId", "main")
        val manager = getManager() ?: return error("900010", "ResourceManager not available")
        val version = manager.getLocalVersion(moduleId)
        return buildJsonObject {
            put("moduleId", JsonPrimitive(moduleId))
            put("version", JsonPrimitive(version))
        }.let { success(it) }
    }

    private fun getAllVersions(): JsonElement {
        val manager = getManager() ?: return error("900010", "ResourceManager not available")
        val versions = manager.getAllVersions()
        return buildJsonObject {
            put("versions", kotlinx.serialization.json.buildJsonObject {
                versions.forEach { (k, v) -> put(k, JsonPrimitive(v)) }
            })
        }.let { success(it) }
    }

    private fun checkUpdate(params: JsonObject?): JsonElement {
        val moduleId = getParam(params, "moduleId", "main")
        val remoteVersion = getParam(params, "remoteVersion")
        if (remoteVersion.isEmpty()) {
            return error("900001", "remoteVersion is required")
        }
        val manager = getManager() ?: return error("900010", "ResourceManager not available")
        val needsUpdate = manager.needsUpdate(moduleId, remoteVersion)
        return buildJsonObject {
            put("moduleId", JsonPrimitive(moduleId))
            put("localVersion", JsonPrimitive(manager.getLocalVersion(moduleId)))
            put("remoteVersion", JsonPrimitive(remoteVersion))
            put("needsUpdate", JsonPrimitive(needsUpdate))
        }.let { success(it) }
    }

    private suspend fun applyUpdate(params: JsonObject?): JsonElement {
        val moduleId = getParam(params, "moduleId", "main")
        val version = getParam(params, "version")
        val downloadUrl = getParam(params, "downloadUrl")
        val md5 = getParam(params, "md5")

        if (downloadUrl.isEmpty()) {
            return error("900001", "downloadUrl is required")
        }

        val manager = getManager() ?: return error("900010", "ResourceManager not available")
        val updateInfo = OfflineResourceManager.UpdateInfo(
            moduleId = moduleId,
            version = version,
            downloadUrl = downloadUrl,
            md5 = md5
        )

        val result = manager.applyUpdate(updateInfo)
        return buildJsonObject {
            put("success", JsonPrimitive(result))
            put("moduleId", JsonPrimitive(moduleId))
            put("version", JsonPrimitive(version))
        }.let { success(it) }
    }

    private fun getManager(): OfflineResourceManager? {
        // Access via CoconutSDK singleton
        val ctx = componentContext?.applicationContext ?: return null
        return CoconutResourceHolder.get(ctx)
    }

    override suspend fun onCleanup() {
        componentContext = null
    }
}
