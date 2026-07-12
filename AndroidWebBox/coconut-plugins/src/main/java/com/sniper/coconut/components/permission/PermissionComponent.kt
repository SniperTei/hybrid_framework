package com.sniper.coconut.components.permission

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.sniper.coconut.component.BaseComponent
import com.sniper.coconut.component.ComponentContext
import com.sniper.coconut.component.ComponentMetadata
import com.sniper.coconut.utils.Logger
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Permission Component
 *
 * Unified permission checking and requesting.
 * Requires Activity via ComponentHost.
 */
@ComponentMetadata(
    name = "permission",
    version = "1.0.0",
    description = "Unified permission management component"
)
class PermissionComponent : BaseComponent() {

    override val name = "permission"
    override val version = "1.0.0"
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
     * Request a permission (launches system permission dialog)
     * params: { "permission": "android.permission.CAMERA" }
     *
     * Note: This initiates the request. The result comes via ActivityCompat callbacks.
     * H5 should call check() afterward to verify.
     */
    private fun requestPermission(params: JsonObject?): JsonElement {
        val permission = getParam(params, "permission")
        if (permission.isEmpty()) {
            return paramValidationError("Permission name required")
        }

        val activity = componentContext?.currentActivity
        if (activity == null || activity.isFinishing) {
            return internalError("Activity not available")
        }

        // Already granted?
        val context = componentContext!!.applicationContext
        if (ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED) {
            return buildJsonObject {
                put("permission", JsonPrimitive(permission))
                put("status", JsonPrimitive("authorized"))
                put("granted", JsonPrimitive(true))
            }.let { success(it) }
        }

        // Request the permission
        activity.runOnUiThread {
            ActivityCompat.requestPermissions(activity, arrayOf(permission), PERMISSION_REQUEST_CODE)
        }

        Logger.d(name, "Requesting permission: $permission")
        return buildJsonObject {
            put("permission", JsonPrimitive(permission))
            put("status", JsonPrimitive("notDetermined"))
            put("requested", JsonPrimitive(true))
        }.let { success(it) }
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

    companion object {
        private const val PERMISSION_REQUEST_CODE = 1001
    }

    override suspend fun onCleanup() {
        componentContext = null
    }
}
