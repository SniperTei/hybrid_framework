package com.sniper.coconutandroidapp.components.dialog

import android.app.Activity
import android.app.AlertDialog
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.ProgressBar
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
    override val methods = listOf("alert", "confirm", "toast", "showLoading", "hideLoading")

    private var componentContext: ComponentContext? = null
    private var loadingDialog: AlertDialog? = null

    override suspend fun onInit(context: ComponentContext) {
        componentContext = context
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
    private suspend fun alert(params: JsonObject?): JsonElement {
        val activity = getActivity()
        if (activity == null || activity.isFinishing) {
            return internalError("Activity not available")
        }

        val title = getParam(params, "title", "提示")
        val message = getParam(params, "message", "")
        val buttonText = getParam(params, "buttonText", "确定")

        return suspendCancellableCoroutine { cont ->
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
    }

    /**
     * Show a confirm dialog with OK/Cancel buttons
     */
    private suspend fun confirm(params: JsonObject?): JsonElement {
        val activity = getActivity()
        if (activity == null || activity.isFinishing) {
            return internalError("Activity not available")
        }

        val title = getParam(params, "title", "确认")
        val message = getParam(params, "message", "")
        val okText = getParam(params, "confirmText", "确定")
        val cancelText = getParam(params, "cancelText", "取消")

        return suspendCancellableCoroutine { cont ->
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
    }

    /**
     * Show a native Toast
     */
    private fun toast(params: JsonObject?): JsonElement {
        val message = getParam(params, "message", "")
        if (message.isEmpty()) {
            return paramValidationError("Message cannot be empty")
        }
        // duration 单位为秒（跨端契约）；native Toast 仅支持 SHORT/LONG，按 3 秒阈值映射
        val durationSec = getIntParam(params, "duration", 2)
        val position = getParam(params, "position", "bottom")

        val activity = getActivity()
        val host: ComponentHost? = componentContext?.host

        val runToast = {
            val toastDuration = if (durationSec >= 3) Toast.LENGTH_LONG else Toast.LENGTH_SHORT
            val toast = Toast.makeText(activity ?: componentContext?.applicationContext, message, toastDuration)
            // position 尽力支持：文本 toast 在 API 30+ 忽略 gravity，属平台限制
            when (position) {
                "top" -> toast.setGravity(Gravity.TOP, 0, 100)
                "center" -> toast.setGravity(Gravity.CENTER, 0, 0)
            }
            toast.show()
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
     * Show a loading dialog (AlertDialog + ProgressBar, ProgressDialog is deprecated)
     */
    private fun showLoading(params: JsonObject?): JsonElement {
        val activity = getActivity()
        if (activity == null || activity.isFinishing) {
            return internalError("Activity not available")
        }

        val message = getParam(params, "message", "加载中...")

        activity.runOnUiThread {
            hideLoadingInternal()
            val content = LinearLayout(activity).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(48, 32, 48, 32)
                addView(ProgressBar(activity).apply {
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    )
                })
                addView(TextView(activity).apply {
                    text = message
                    textSize = 15f
                    setPadding(32, 0, 0, 0)
                })
            }
            loadingDialog = AlertDialog.Builder(activity)
                .setView(content)
                .setCancelable(false)
                .create()
            loadingDialog?.show()
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
        Logger.d(name, "Dialog component cleanup complete")
    }
}
