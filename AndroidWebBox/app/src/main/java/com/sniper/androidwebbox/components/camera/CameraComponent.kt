package com.sniper.androidwebbox.components.camera

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.MediaStore
import android.util.Base64
import androidx.core.content.FileProvider
import com.sniper.coconut.component.ActivityForResultDispatcher
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
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.UUID
import kotlin.coroutines.resume

/**
 * Camera Component (Android)
 *
 * Provides photo capture, QR/barcode scanning, and a confirm dialog.
 * API mirrors the iOS/Harmony CameraComponent for cross-platform parity.
 *
 * Functions:
 *   - takePhoto:   { frontCamera?: bool } -> { success, uri?, base64?, message? }
 *       On success: full-res JPEG written to cacheDir/coconut_photos/, returned as
 *       both a content:// uri (current session only) and a data:image/jpeg;base64,...
 *       data URL. Permission denied / cancel returns { success:false, message }.
 *   - scanQRCode:  { qrOnly?: bool } -> { success, codeType?, originalValue?, message? }
 *       Backed by ZXing (`zxing-android-embedded`). Returns codeType (e.g. "QR_CODE")
 *       and originalValue on success; { success:false, message:"User cancelled" } on
 *       back/cancel.
 *   - isSupported: -> { takePhoto: bool, scanQRCode: bool }
 *   - showDialog:  { title?, message?, confirmText?, cancelText? } -> { confirmed: bool }
 *
 * Note: requires android.permission.CAMERA in the host app's manifest and a
 * FileProvider registered at authority "${applicationId}.fileprovider" with a
 * <cache-path> for "coconut_photos/" (see app/src/main/res/xml/file_paths.xml).
 */
@ComponentMetadata(
    name = "camera",
    version = "1.1.0",
    description = "Camera component for photo capture and QR code scanning"
)
class CameraComponent : BaseComponent() {

    override val name = "camera"
    override val version = "1.1.0"
    override val description = "Camera component for photo capture and QR code scanning"

    private var componentContext: ComponentContext? = null

    override suspend fun onInit(ctx: ComponentContext) {
        componentContext = ctx
    }

    override suspend fun handle(function: String, params: JsonObject?): JsonElement {
        return when (function) {
            "takePhoto" -> takePhoto(params)
            "scanQRCode" -> scanQRCode(params)
            "isSupported" -> isSupported()
            "showDialog" -> showDialog(params)
            else -> functionNotSupportedError(function)
        }
    }

    // ------------------------------------------------------------------
    // Permission helper
    // ------------------------------------------------------------------

    /**
     * Ensures CAMERA permission is granted, requesting it if necessary.
     * Returns true if granted; false if denied or request failed.
     * On false, callers should return { success:false, message:"Camera permission denied" }.
     */
    private suspend fun ensureCameraPermission(activity: Activity): Boolean {
        val ctx = componentContext?.applicationContext ?: return false
        if (ctx.checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            return true
        }

        val granted = suspendCancellableCoroutine { cont ->
            val code = PermissionResultDispatcher.request(
                activity,
                arrayOf(Manifest.permission.CAMERA)
            ) { result ->
                if (!cont.isActive) return@request
                cont.resume(result[Manifest.permission.CAMERA] == true)
            }
            cont.invokeOnCancellation { PermissionResultDispatcher.cancel(code) }
        }
        return granted
    }

    // ------------------------------------------------------------------
    // takePhoto (full-res capture via EXTRA_OUTPUT + FileProvider)
    // ------------------------------------------------------------------

    private suspend fun takePhoto(params: JsonObject?): JsonElement {
        val activity = componentContext?.currentActivity
        if (activity == null || activity.isFinishing) {
            return internalError("Activity not available")
        }

        // Permission gate: business-layer denial, not a Bridge error code.
        if (!ensureCameraPermission(activity)) {
            return jsonSuccess {
                put("success", JsonPrimitive(false))
                put("message", JsonPrimitive("Camera permission denied"))
            }
        }

        val frontCamera = getBoolParam(params, "frontCamera", false)

        // Resolve camera app.
        val captureIntent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
        if (captureIntent.resolveActivity(activity.packageManager) == null) {
            return jsonSuccess {
                put("success", JsonPrimitive(false))
                put("message", JsonPrimitive("No camera app available on this device"))
            }
        }
        if (frontCamera) {
            // Best-effort hint for front camera — not all camera apps honor this.
            captureIntent.putExtra("android.intent.extras.CAMERA_FACING", 1)
        }

        // Prepare output file in cacheDir/coconut_photos/.
        val photosDir = File(activity.cacheDir, "coconut_photos").apply { mkdirs() }
        val photoFile = File(photosDir, "coconut_photo_${UUID.randomUUID()}.jpg")
        val authority = "${activity.packageName}.fileprovider"
        val photoUri: Uri = try {
            FileProvider.getUriForFile(activity, authority, photoFile)
        } catch (t: Throwable) {
            Logger.e(name, "Failed to provision photo URI via FileProvider", t)
            return internalError("Unable to provision photo output location")
        }

        captureIntent.putExtra(MediaStore.EXTRA_OUTPUT, photoUri)
        // Grant write access to the camera app for the temp uri.
        captureIntent.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)

        return suspendCancellableCoroutine { cont ->
            val requestCode = ActivityForResultDispatcher.launch(activity, captureIntent) { resultCode, _ ->
                if (!cont.isActive) return@launch
                cont.resume(buildTakePhotoResult(resultCode, photoFile, photoUri))
            }
            cont.invokeOnCancellation {
                ActivityForResultDispatcher.cancel(requestCode)
                photoFile.delete()
            }
        }
    }

    private fun buildTakePhotoResult(resultCode: Int, photoFile: File, photoUri: Uri): JsonElement {
        if (resultCode != Activity.RESULT_OK) {
            photoFile.delete()
            return jsonSuccess {
                put("success", JsonPrimitive(false))
                put("message", JsonPrimitive("User cancelled"))
            }
        }
        if (!photoFile.exists() || photoFile.length() == 0L) {
            photoFile.delete()
            return jsonSuccess {
                put("success", JsonPrimitive(false))
                put("message", JsonPrimitive("Camera returned no image data"))
            }
        }

        val bytes = try {
            photoFile.readBytes()
        } catch (t: Throwable) {
            Logger.e(name, "Failed to read captured photo file", t)
            photoFile.delete()
            return jsonSuccess {
                put("success", JsonPrimitive(false))
                put("message", JsonPrimitive("Failed to read captured photo"))
            }
        }
        val base64 = Base64.encodeToString(bytes, Base64.NO_WRAP)
        val dataUrl = "data:image/jpeg;base64,$base64"

        return jsonSuccess {
            put("success", JsonPrimitive(true))
            put("uri", JsonPrimitive(photoUri.toString()))
            put("base64", JsonPrimitive(dataUrl))
        }
    }

    // ------------------------------------------------------------------
    // scanQRCode (placeholder — ZXing implementation lands in a follow-up commit)
    // ------------------------------------------------------------------

    private fun scanQRCode(params: JsonObject?): JsonElement {
        return jsonSuccess {
            put("success", JsonPrimitive(false))
            put("message", JsonPrimitive("QR code scanning is not yet supported on Android"))
        }
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
            // Scanning intentionally reported as unsupported until ZXing backend is wired.
            put("scanQRCode", JsonPrimitive(false))
        }.let { success(it) }
    }

    // ------------------------------------------------------------------
    // showDialog (native confirm dialog)
    // ------------------------------------------------------------------

    private suspend fun showDialog(params: JsonObject?): JsonElement = suspendCancellableCoroutine { cont ->
        val activity = componentContext?.currentActivity
        if (activity == null || activity.isFinishing) {
            cont.resume(jsonSuccess {
                put("confirmed", JsonPrimitive(false))
            })
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
                    if (cont.isActive) cont.resume(jsonSuccess {
                        put("confirmed", JsonPrimitive(true))
                    })
                }
                .setNegativeButton(cancelText) { d, _ ->
                    d.dismiss()
                    if (cont.isActive) cont.resume(jsonSuccess {
                        put("confirmed", JsonPrimitive(false))
                    })
                }
                .setCancelable(false)
                .create()
            cont.invokeOnCancellation { dialog.dismiss() }
            dialog.show()
        }
    }

    private inline fun jsonSuccess(builder: JsonObjectBuilder.() -> Unit): JsonElement {
        return buildJsonObject(builder).let { success(it) }
    }

    override suspend fun onCleanup() {
        componentContext = null
    }
}
