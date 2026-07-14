package com.sniper.androidwebbox.components.camera

import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.provider.MediaStore
import android.util.Base64
import com.sniper.coconut.component.ActivityForResultDispatcher
import com.sniper.coconut.component.BaseComponent
import com.sniper.coconut.component.ComponentContext
import com.sniper.coconut.component.ComponentMetadata
import com.sniper.coconut.utils.Logger
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import java.io.ByteArrayOutputStream
import kotlin.coroutines.resume

/**
 * Camera Component (Android)
 *
 * Provides photo capture, QR/barcode scanning, and a confirm dialog.
 * API mirrors the iOS/Harmony CameraComponent for cross-platform parity.
 *
 * Functions:
 *   - takePhoto:   { frontCamera?: bool } -> { success, base64?, message? }
 *       base64 is a data URL (image/jpeg) ready for <img src>.
 *       Returns { success: false, message } when the user cancels.
 *   - scanQRCode:  currently returns { success: false, message } (not yet implemented).
 *   - isSupported: -> { takePhoto: bool, scanQRCode: bool }
 *   - showDialog:  { title?, message?, confirmText?, cancelText? } -> { confirmed: bool }
 *
 * Note: requires android.permission.CAMERA in the host app's manifest.
 */
@ComponentMetadata(
    name = "camera",
    version = "1.0.0",
    description = "Camera component for photo capture and QR code scanning"
)
class CameraComponent : BaseComponent() {

    override val name = "camera"
    override val version = "1.0.0"
    override val description = "Camera component for photo capture and QR code scanning"

    private var componentContext: ComponentContext? = null

    override suspend fun onInit(ctx: ComponentContext) {
        componentContext = ctx
    }

    override suspend fun handle(function: String, params: JsonObject?): JsonElement {
        return when (function) {
            "takePhoto" -> takePhoto(params)
            "scanQRCode" -> scanQRCodeStub()
            "isSupported" -> isSupported()
            "showDialog" -> showDialog(params)
            else -> functionNotSupportedError(function)
        }
    }

    // ------------------------------------------------------------------
    // takePhoto
    // ------------------------------------------------------------------

    /**
     * Launch the system camera app to capture a photo.
     * Uses MediaStore.ACTION_IMAGE_CAPTURE which returns a thumbnail bitmap
     * in the "data" extra of the result intent.
     */
    private suspend fun takePhoto(params: JsonObject?): JsonElement {
        val activity = componentContext?.currentActivity
        if (activity == null || activity.isFinishing) {
            return internalError("Activity not available")
        }

        val frontCamera = getBoolParam(params, "frontCamera", false)

        // Verify the system has a camera activity to handle the intent.
        val captureIntent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
        if (captureIntent.resolveActivity(activity.packageManager) == null) {
            return buildJsonObject {
                put("success", JsonPrimitive(false))
                put("message", JsonPrimitive("No camera app available on this device"))
            }.let { success(it) }
        }

        if (frontCamera) {
            // Best-effort hint for front camera — not all camera apps honor this.
            captureIntent.putExtra("android.intent.extras.CAMERA_FACING", 1)
        }

        return suspendCancellableCoroutine { cont ->
            val requestCode = ActivityForResultDispatcher.launch(activity, captureIntent) { resultCode, data ->
                if (!cont.isActive) return@launch
                cont.resume(buildTakePhotoResult(resultCode, data))
            }
            cont.invokeOnCancellation {
                ActivityForResultDispatcher.cancel(requestCode)
            }
        }
    }

    private fun buildTakePhotoResult(resultCode: Int, data: Intent?): JsonElement {
        if (resultCode != Activity.RESULT_OK) {
            return buildJsonObject {
                put("success", JsonPrimitive(false))
                put("message", JsonPrimitive("User cancelled"))
            }.let { success(it) }
        }

        val bitmap = data?.extras?.get("data") as? Bitmap
        if (bitmap == null) {
            return buildJsonObject {
                put("success", JsonPrimitive(false))
                put("message", JsonPrimitive("No image data returned"))
            }.let { success(it) }
        }

        val dataUrl = bitmapToJpegDataUrl(bitmap, quality = 80)
        return buildJsonObject {
            put("success", JsonPrimitive(true))
            put("base64", JsonPrimitive(dataUrl))
        }.let { success(it) }
    }

    /**
     * Encode a Bitmap as a base64 data URL (image/jpeg).
     */
    private fun bitmapToJpegDataUrl(bitmap: Bitmap, quality: Int): String {
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, quality, stream)
        val base64 = Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
        return "data:image/jpeg;base64,$base64"
    }

    // ------------------------------------------------------------------
    // scanQRCode (stub)
    // ------------------------------------------------------------------

    private fun scanQRCodeStub(): JsonElement {
        return buildJsonObject {
            put("success", JsonPrimitive(false))
            put("message", JsonPrimitive("QR code scanning is not yet supported on Android"))
        }.let { success(it) }
    }

    // ------------------------------------------------------------------
    // isSupported
    // ------------------------------------------------------------------

    private fun isSupported(): JsonElement {
        val ctx = componentContext?.applicationContext
        val hasCameraFeature = ctx?.packageManager
            ?.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY) == true
        val cameraIntent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
        val canCapture = hasCameraFeature &&
            (ctx?.packageManager?.let { cameraIntent.resolveActivity(it) != null } == true)

        return buildJsonObject {
            put("takePhoto", JsonPrimitive(canCapture))
            // Scanning intentionally reported as unsupported until QR backend is wired.
            put("scanQRCode", JsonPrimitive(false))
        }.let { success(it) }
    }

    // ------------------------------------------------------------------
    // showDialog (native confirm dialog)
    // ------------------------------------------------------------------

    private suspend fun showDialog(params: JsonObject?): JsonElement = suspendCancellableCoroutine { cont ->
        val activity = componentContext?.currentActivity
        if (activity == null || activity.isFinishing) {
            cont.resume(buildJsonObject {
                put("confirmed", JsonPrimitive(false))
            }.let { success(it) })
            return@suspendCancellableCoroutine
        }

        val title = getParam(params, "title", "提示")
        val message = getParam(params, "message", "")
        val confirmText = getParam(params, "confirmText", "确定")
        val cancelText = getParam(params, "cancelText", "取消")

        activity.runOnUiThread {
            val dialog = AlertDialog.Builder(activity)
                .setTitle(title)
                .setMessage(message)
                .setPositiveButton(confirmText) { d, _ ->
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

    override suspend fun onCleanup() {
        componentContext = null
    }
}
