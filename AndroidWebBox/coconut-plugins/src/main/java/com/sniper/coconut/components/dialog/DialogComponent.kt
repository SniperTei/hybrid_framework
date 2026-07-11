package com.sniper.coconut.components.dialog

import android.app.Activity
import android.app.AlertDialog
import android.app.ProgressDialog
import android.view.Gravity
import android.widget.TextView
import android.widget.Toast
import com.sniper.coconut.component.BaseComponent
import com.sniper.coconut.component.ComponentContext
import com.sniper.coconut.component.ComponentHost
import com.sniper.coconut.component.ComponentMetadata
import com.sniper.coconut.utils.Logger
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlin.coroutines.resume

/**
 * Dialog Component
 *
 * Provides native dialogs (Alert, Confirm, Loading, Toast).
 * Requires Activity via ComponentHost.
 */
@ComponentMetadata(
    name = "dialog",
    version = "1.0.0",
    description = "Native dialog and toast component"
)
class DialogComponent : BaseComponent() {

    override val name = "dialog"
    override val version = "1.0.0"
    override val description = "Native dialog and toast component"

    private var componentContext: ComponentContext? = null
    private var loadingDialog: ProgressDialog? = null

    override suspend fun onInit(ctx: ComponentContext) {
        componentContext = ctx
    }

    override suspend fun handle(function: String, params: JsonObject?): JsonElement {
        return when (function) {
            "alert" -> alert(params)
            "confirm" -> confirm(params)
            "toast" -> toast(params)
            "showLoading" -> showLoading(params)
            "hideLoading" -> hideLoading()
            else -> functionNotSupportedError(function)
        }
    }

    private fun getActivity(): Activity? = componentContext?.currentActivity

    /**
     * Show an alert dialog with a single OK button
     */
    private suspend fun alert(params: JsonObject?): JsonElement = suspendCancellableCoroutine { cont ->
        val activity = getActivity()
        if (activity == null || activity.isFinishing) {
            cont.resume(internalError("Activity not available"))
            return@suspendCancellableCoroutine
        }

        val title = getParam(params, "title", "提示")
        val message = getParam(params, "message", "")
        val buttonText = getParam(params, "buttonText", "确定")

        activity.runOnUiThread {
            val dialog = AlertDialog.Builder(activity)
                .setTitle(title)
                .setMessage(message)
                .setPositiveButton(buttonText) { d, _ ->
                    d.dismiss()
                    if (cont.isActive) cont.resume(buildJsonObject {
                        put("confirmed", JsonPrimitive(true))
                    }.let { success(it) })
                }
                .setCancelable(false)
                .create()

            cont.invokeOnCancellation { dialog.dismiss() }
            dialog.show()
        }
    }

    /**
     * Show a confirm dialog with OK/Cancel buttons
     */
    private suspend fun confirm(params: JsonObject?): JsonElement = suspendCancellableCoroutine { cont ->
        val activity = getActivity()
        if (activity == null || activity.isFinishing) {
            cont.resume(internalError("Activity not available"))
            return@suspendCancellableCoroutine
        }

        val title = getParam(params, "title", "确认")
        val message = getParam(params, "message", "")
        val okText = getParam(params, "okText", "确定")
        val cancelText = getParam(params, "cancelText", "取消")

        activity.runOnUiThread {
            val dialog = AlertDialog.Builder(activity)
                .setTitle(title)
                .setMessage(message)
                .setPositiveButton(okText) { d, _ ->
                    d.dismiss()
                    if (cont.isActive) cont.resume(buildJsonObject {
                        put("confirmed", JsonPrimitive(true))
                    }.let { success(it) })
                }
                .setNegativeButton(cancelText) { d, _ ->
                    d.dismiss()
                    if (cont.isActive) cont.resume(buildJsonObject {
                        put("confirmed", JsonPrimitive(false))
                    }.let { success(it) })
                }
                .setCancelable(false)
                .create()

            cont.invokeOnCancellation { dialog.dismiss() }
            dialog.show()
        }
    }

    /**
     * Show a native Toast
     */
    private fun toast(params: JsonObject?): JsonElement {
        val message = getParam(params, "message", "")
        val duration = getParam(params, "duration", "short")
        if (message.isEmpty()) {
            return paramValidationError("Message cannot be empty")
        }

        val activity = getActivity()
        val host = componentContext?.host

        val runToast = {
            val toastDuration = if (duration == "long") Toast.LENGTH_LONG else Toast.LENGTH_SHORT
            Toast.makeText(activity ?: componentContext?.applicationContext, message, toastDuration).show()
        }

        if (activity != null && !activity.isFinishing) {
            activity.runOnUiThread(runToast)
        } else {
            host?.runOnMainThread(runToast) ?: runToast()
        }

        return buildJsonObject {
            put("success", JsonPrimitive(true))
        }.let { success(it) }
    }

    /**
     * Show a loading dialog
     */
    private fun showLoading(params: JsonObject?): JsonElement {
        val activity = getActivity()
        if (activity == null || activity.isFinishing) {
            return internalError("Activity not available")
        }

        val title = getParam(params, "title", "")
        val message = getParam(params, "message", "加载中...")

        activity.runOnUiThread {
            hideLoadingInternal()
            loadingDialog = ProgressDialog(activity).apply {
                setTitle(title)
                setMessage(message)
                setCancelable(false)
                show()
            }
        }

        return buildJsonObject {
            put("success", JsonPrimitive(true))
        }.let { success(it) }
    }

    /**
     * Hide loading dialog
     */
    private fun hideLoading(): JsonElement {
        getActivity()?.runOnUiThread { hideLoadingInternal() }
        return buildJsonObject {
            put("success", JsonPrimitive(true))
        }.let { success(it) }
    }

    private fun hideLoadingInternal() {
        loadingDialog?.dismiss()
        loadingDialog = null
    }

    override suspend fun onCleanup() {
        hideLoadingInternal()
        componentContext = null
    }
}
