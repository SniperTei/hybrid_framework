package com.sniper.androidwebbox.components.permission

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import androidx.core.content.ContextCompat
import com.sniper.coconut.component.BaseComponent
import com.sniper.coconut.component.ComponentContext
import com.sniper.coconut.component.ComponentMetadata
import com.sniper.coconut.component.PermissionResultDispatcher
import com.sniper.coconut.utils.Logger
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonObjectBuilder
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlin.coroutines.resume

/**
 * Permission Component
 *
 * Unified permission checking and requesting.
 * Requires Activity via ComponentHost.
 *
 * `request` now suspends until the user responds to the system permission
 * dialog (routed through PermissionResultDispatcher), so the result reflects
 * the actual grant/deny decision. Previously it was fire-and-forget and H5
 * had to poll `check()` afterward.
 */
@ComponentMetadata(
    name = "permission",
    version = "1.1.0",
    description = "Unified permission management component"
)
class PermissionComponent : BaseComponent() {

    override val name = "permission"
    override val version = "1.1.0"
    override val description = "Unified permission management component"

    private var componentContext: ComponentContext? = null

    override suspend fun onInit(ctx: ComponentContext) {
        componentContext = ctx
    }

    override suspend fun handle(function: String, params: JsonObject?): JsonElement {
        return when (function) {
            "check" -> checkPermission(params)
            "request" -> requestPermission(params)
            "openSettings" -> openSettings()
            else -> functionNotSupportedError(function)
        }
    }

    /**
     * Check if a permission is granted
     * params: { "permission": "android.permission.CAMERA" }
     */
    private fun checkPermission(params: JsonObject?): JsonElement {
        val permission = getParam(params, "permission")
        if (permission.isEmpty()) {
            return paramValidationError("Permission name required")
        }

        val context = componentContext?.applicationContext ?: return internalError("Context not available")
        val granted = ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED

        return buildJsonObject {
            put("permission", JsonPrimitive(permission))
            put("status", JsonPrimitive(if (granted) "authorized" else "denied"))
            put("granted", JsonPrimitive(granted))
        }.let { success(it) }
    }

    /**
     * Request a permission (launches system permission dialog) and suspend
     * until the user responds.
     * params: { "permission": "android.permission.CAMERA" }
     *
     * Returns { permission, status, granted }:
     *   - status="authorized" / granted=true   when already granted or granted via dialog
     *   - status="denied"     / granted=false  when user denied or dialog unavailable
     */
    private suspend fun requestPermission(params: JsonObject?): JsonElement {
        val permission = getParam(params, "permission")
        if (permission.isEmpty()) {
            return paramValidationError("Permission name required")
        }

        val activity = componentContext?.currentActivity
        if (activity == null || activity.isFinishing) {
            return internalError("Activity not available")
        }

        // Fast path: already granted.
        val context = componentContext!!.applicationContext
        if (ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED) {
            return buildResult(permission, granted = true)
        }

        Logger.d(name, "Requesting permission: $permission")

        // Suspend on the dispatcher until the user responds.
        val granted = suspendCancellableCoroutine { cont ->
            val code = PermissionResultDispatcher.request(activity, arrayOf(permission)) { result ->
                if (!cont.isActive) return@request
                cont.resume(result[permission] == true)
            }
            cont.invokeOnCancellation { PermissionResultDispatcher.cancel(code) }
        }

        return buildResult(permission, granted = granted)
    }

    private fun buildResult(permission: String, granted: Boolean): JsonElement {
        return jsonSuccess {
            put("permission", JsonPrimitive(permission))
            put("status", JsonPrimitive(if (granted) "authorized" else "denied"))
            put("granted", JsonPrimitive(granted))
        }
    }

    /**
     * Open app settings page for manual permission grant
     */
    private fun openSettings(): JsonElement {
        val activity = componentContext?.currentActivity
        if (activity == null || activity.isFinishing) {
            return internalError("Activity not available")
        }

        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.fromParts("package", activity.packageName, null)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        activity.startActivity(intent)

        return buildJsonObject {
            put("success", JsonPrimitive(true))
        }.let { success(it) }
    }

    private inline fun jsonSuccess(builder: JsonObjectBuilder.() -> Unit): JsonElement {
        return buildJsonObject(builder).let { success(it) }
    }

    override suspend fun onCleanup() {
        componentContext = null
    }
}
