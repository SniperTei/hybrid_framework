package com.sniper.androidwebbox.components.update

import android.content.Context
import com.sniper.coconut.component.BaseComponent
import com.sniper.coconut.component.ComponentMetadata
import com.sniper.coconut.resource.CoconutResourceHolder
import com.sniper.coconut.resource.OfflineResourceManager
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * Update Component — H5 热更新入口（app 层第 7 个组件）.
 *
 * - check({manifestUrl, moduleId?}): query the update server. Caches the
 *   manifest + derived baseUrl as component state; the manifest itself is
 *   never handed to H5.
 * - apply({}): consume the cached check state (no params). Not checked yet
 *   → business failure "check first".
 * - rollback({}): restore the previous version of the module.
 * - version({}): current local module version.
 *
 * All heavy work delegates to OfflineResourceManager on the coroutine the
 * bridge already runs handlers on (same precedent as NavigatorComponent —
 * the Android bridge must not block on network/IO).
 *
 * Failure conventions: missing manifestUrl → bridge error 200007; update
 * server / state-machine failures → code 000000 + success:false (business
 * layer, same as permission-denied).
 *
 * Test seams: all manager operations are injectable lambids (UpdateDeps);
 * the default wiring goes through CoconutResourceHolder.
 */
@ComponentMetadata(
    name = "update",
    version = "1.0.0",
    description = "Hot update component (check/apply/rollback/version)",
    dependencies = []
)
class UpdateComponent internal constructor(
    private val deps: Deps,
) : BaseComponent() {

    /** Manager operations the component uses — injectable for JVM tests. */
    internal class Deps(
        val checkUpdate: suspend (moduleId: String, manifestUrl: String) -> OfflineResourceManager.UpdateCheckResult,
        val performUpdate: suspend (manifest: OfflineResourceManager.RemoteManifest, baseUrl: String) -> OfflineResourceManager.UpdateResult,
        val rollback: suspend (moduleId: String) -> Boolean,
        val localVersion: (moduleId: String) -> String,
    )

    constructor(context: Context) : this(
        Deps(
            checkUpdate = { m, u -> CoconutResourceHolder.get(context).checkUpdate(m, u) },
            performUpdate = { m, b -> CoconutResourceHolder.get(context).performUpdate(m, b) },
            rollback = { m -> CoconutResourceHolder.get(context).rollback(m) },
            localVersion = { m -> CoconutResourceHolder.get(context).getLocalVersion(m) },
        )
    )

    override val name = "update"
    override val version = "1.0.0"
    override val description = "Hot update component (check/apply/rollback/version)"
    override val methods = listOf("check", "apply", "rollback", "version")

    // ---- check state (manifest never crosses the bridge) ----
    private var cachedManifest: OfflineResourceManager.RemoteManifest? = null
    private var cachedBaseUrl: String = ""
    private var moduleId: String = DEFAULT_MODULE_ID

    override suspend fun handle(function: String, params: JsonObject?): JsonElement {
        return when (function) {
            "check" -> check(params)
            "apply" -> apply()
            "rollback" -> rollback()
            "version" -> version()
            else -> functionNotSupportedError(function)
        }
    }

    private suspend fun check(params: JsonObject?): JsonElement {
        val manifestUrl = getParam(params, "manifestUrl")
        if (manifestUrl.isEmpty()) {
            return error("200007", "manifestUrl is required")
        }
        val requestedModule = getParam(params, "moduleId")
        if (requestedModule.isNotEmpty()) moduleId = requestedModule

        val result = deps.checkUpdate(moduleId, manifestUrl)
        if (result.error != null) {
            return businessFailure("check failed: ${result.error}")
        }

        // Cache for a later parameterless apply. baseUrl = manifest URL
        // minus its last path segment (per-file URLs are relative to it).
        if (result.available && result.manifest != null) {
            cachedManifest = result.manifest
            cachedBaseUrl = manifestUrl.substringBeforeLast('/')
        } else {
            cachedManifest = null
        }

        return success(buildJsonObject {
            put("available", result.available)
            put("currentVersion", result.currentVersion)
            put("remoteVersion", result.remoteVersion)
        })
    }

    private suspend fun apply(): JsonElement {
        val manifest = cachedManifest
            ?: return businessFailure("no update available — call check first")
        val result = deps.performUpdate(manifest, cachedBaseUrl)
        if (!result.success) {
            return businessFailure(result.error ?: "apply failed")
        }
        return success(buildJsonObject {
            put("success", true)
            put("moduleId", result.moduleId)
            put("version", result.version)
        })
    }

    private suspend fun rollback(): JsonElement {
        val ok = deps.rollback(moduleId)
        if (!ok) {
            return businessFailure("nothing to roll back")
        }
        return success(buildJsonObject {
            put("success", true)
            put("version", deps.localVersion(moduleId))
        })
    }

    private fun version(): JsonElement =
        success(buildJsonObject {
            put("version", deps.localVersion(moduleId))
        })

    private fun businessFailure(message: String): JsonElement =
        success(buildJsonObject {
            put("success", false)
            put("message", message)
        })

    companion object {
        const val DEFAULT_MODULE_ID = "demo"
    }
}
