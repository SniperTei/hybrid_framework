package com.sniper.hybrid.plugins

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.MediaStore
import android.util.Log
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import com.sniper.hybrid.plugin.BasePlugin
import com.sniper.hybrid.plugin.PluginCallback
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 相机插件
 * 支持拍照功能
 */
class CameraPlugin : BasePlugin() {

    companion object {
        private const val REQUEST_CODE_CAPTURE = 1001
        private const val REQUEST_CODE_PERMISSION = 1002
        private const val PERMISSION_CAMERA = Manifest.permission.CAMERA
    }

    private var currentCallback: PluginCallback? = null
    private var currentPhotoUri: Uri? = null
    private var currentPhotoPath: String? = null

    override fun pluginName() = "camera"

    override fun exec(action: String, params: JSONObject, callback: PluginCallback) {
        if (!ensureAttached()) {
            callback.error("PLUGIN_ERROR", "Plugin not attached")
            return
        }

        when (action) {
            "capture" -> capture(params, callback)
            "isAvailable" -> checkAvailable(callback)
            else -> callback.error("UNKNOWN_ACTION", "Unknown action: $action")
        }
    }

    /**
     * 拍照
     */
    private fun capture(params: JSONObject, callback: PluginCallback) {
        val context = requireContext().getContext()

        // 检查相机权限
        if (!checkCameraPermission()) {
            requestCameraPermission()
            currentCallback = callback
            return
        }

        // 检查相机是否可用
        if (!context.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)) {
            callback.error("UNAVAILABLE", "Camera not available on this device")
            return
        }

        currentCallback = callback

        // 创建拍照Intent
        val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
            // 创建临时文件保存照片
            val photoFile = createImageFile()
            currentPhotoPath = photoFile.absolutePath

            // 获取FileProvider URI
            currentPhotoUri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                photoFile
            )

            putExtra(MediaStore.EXTRA_OUTPUT, currentPhotoUri)
        }

        try {
            requireContext().startActivityForResult(intent, REQUEST_CODE_CAPTURE)
        } catch (e: ActivityNotFoundException) {
            callback.error("NO_CAMERA_APP", "No camera app available")
            currentCallback = null
        } catch (e: Exception) {
            Log.e(pluginName(), "Error starting camera", e)
            callback.error("CAMERA_ERROR", e.message)
            currentCallback = null
        }
    }

    /**
     * 检查相机是否可用
     */
    private fun checkAvailable(callback: PluginCallback) {
        val context = requireContext().getContext()
        val available = context.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)
        callback.success(mapOf("available" to available))
    }

    /**
     * 检查相机权限
     */
    private fun checkCameraPermission(): Boolean {
        val context = requireContext().getContext()
        return ContextCompat.checkSelfPermission(
            context,
            PERMISSION_CAMERA
        ) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * 请求相机权限
     */
    private fun requestCameraPermission() {
        requireContext().requestPermissions(arrayOf(PERMISSION_CAMERA), REQUEST_CODE_PERMISSION)
    }

    /**
     * 创建图片文件
     */
    private fun createImageFile(): File {
        val timeStamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val storageDir = File(requireContext().getContext().getExternalFilesDir(null), "Pictures")
        if (!storageDir.exists()) {
            storageDir.mkdirs()
        }
        return File(storageDir, "IMG_${timeStamp}.jpg")
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == REQUEST_CODE_CAPTURE) {
            val callback = currentCallback ?: return false

            if (resultCode == android.app.Activity.RESULT_OK) {
                // 拍照成功
                val photoPath = currentPhotoPath
                if (photoPath != null && File(photoPath).exists()) {
                    callback.success(mapOf(
                        "path" to photoPath,
                        "uri" to (currentPhotoUri?.toString() ?: "")
                    ))
                } else {
                    callback.error("FILE_ERROR", "Photo file not found")
                }
            } else {
                // 用户取消或拍照失败
                callback.error("CANCELLED", "Camera operation cancelled")
            }

            // 清理
            currentCallback = null
            currentPhotoUri = null
            currentPhotoPath = null
            return true
        }
        return false
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode == REQUEST_CODE_PERMISSION) {
            val callback = currentCallback ?: return false

            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                // 权限授予成功，继续拍照
                callback.success(mapOf("granted" to true))
                // 这里需要重新触发capture
            } else {
                // 权限被拒绝
                callback.error("PERMISSION_DENIED", "Camera permission denied")
            }

            currentCallback = null
            return true
        }
        return false
    }
}
