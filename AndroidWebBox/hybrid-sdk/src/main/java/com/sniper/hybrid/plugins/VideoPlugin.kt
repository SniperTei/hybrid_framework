package com.sniper.hybrid.plugins

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.MediaStore
import android.util.Log
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
 * 录像插件
 * 支持录制视频功能
 */
class VideoPlugin : BasePlugin() {

    companion object {
        private const val REQUEST_CODE_RECORD = 3001
        private const val REQUEST_CODE_PERMISSION = 3002
    }

    private var currentCallback: PluginCallback? = null
    private var currentVideoUri: Uri? = null
    private var currentVideoPath: String? = null

    override fun pluginName() = "video"

    override fun exec(action: String, params: JSONObject, callback: PluginCallback) {
        if (!ensureAttached()) {
            callback.error("PLUGIN_ERROR", "Plugin not attached")
            return
        }

        when (action) {
            "record" -> record(params, callback)
            "isAvailable" -> checkAvailable(callback)
            else -> callback.error("UNKNOWN_ACTION", "Unknown action: $action")
        }
    }

    /**
     * 录像
     */
    private fun record(params: JSONObject, callback: PluginCallback) {
        val context = requireContext().getContext()

        // 检查相机权限
        if (!checkCameraPermission()) {
            requestCameraPermission()
            currentCallback = callback
            return
        }

        // 检查录音权限
        if (!checkAudioPermission()) {
            requestAudioPermission()
            currentCallback = callback
            return
        }

        // 检查相机是否可用
        if (!context.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)) {
            callback.error("UNAVAILABLE", "Camera not available on this device")
            return
        }

        currentCallback = callback

        // 获取录像参数
        val maxDuration = optInt(params, "max_duration", 0) // 0表示无限制
        val quality = optInt(params, "quality", 1) // 0=低, 1=高

        // 创建录像Intent
        val intent = Intent(MediaStore.ACTION_VIDEO_CAPTURE).apply {
            // 创建临时文件保存视频
            val videoFile = createVideoFile()
            currentVideoPath = videoFile.absolutePath

            // 获取FileProvider URI
            currentVideoUri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                videoFile
            )

            putExtra(MediaStore.EXTRA_OUTPUT, currentVideoUri)

            // 设置最大时长（秒）
            if (maxDuration > 0) {
                putExtra(MediaStore.EXTRA_DURATION_LIMIT, maxDuration)
            }

            // 设置视频质量
            putExtra(MediaStore.EXTRA_VIDEO_QUALITY, quality)
        }

        try {
            requireContext().startActivityForResult(intent, REQUEST_CODE_RECORD)
        } catch (e: ActivityNotFoundException) {
            callback.error("NO_CAMERA_APP", "No camera app available")
            currentCallback = null
        } catch (e: Exception) {
            Log.e(pluginName(), "Error starting video recording", e)
            callback.error("VIDEO_ERROR", e.message)
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
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * 检查录音权限
     */
    private fun checkAudioPermission(): Boolean {
        val context = requireContext().getContext()
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * 请求相机和录音权限
     */
    private fun requestCameraPermission() {
        requireContext().requestPermissions(
            arrayOf(Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO),
            REQUEST_CODE_PERMISSION
        )
    }

    private fun requestAudioPermission() {
        requireContext().requestPermissions(
            arrayOf(Manifest.permission.RECORD_AUDIO),
            REQUEST_CODE_PERMISSION
        )
    }

    /**
     * 创建视频文件
     */
    private fun createVideoFile(): File {
        val timeStamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val storageDir = File(requireContext().getContext().getExternalFilesDir(null), "Videos")
        if (!storageDir.exists()) {
            storageDir.mkdirs()
        }
        return File(storageDir, "VID_${timeStamp}.mp4")
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == REQUEST_CODE_RECORD) {
            val callback = currentCallback ?: return false

            if (resultCode == android.app.Activity.RESULT_OK) {
                // 录像成功
                val videoPath = currentVideoPath
                if (videoPath != null && File(videoPath).exists()) {
                    // 获取视频信息
                    val videoFile = File(videoPath)
                    val size = videoFile.length()

                    callback.success(mapOf(
                        "path" to videoPath,
                        "uri" to (currentVideoUri?.toString() ?: ""),
                        "size" to size,
                        "size_mb" to String.format("%.2f", size / (1024.0 * 1024.0))
                    ))
                } else {
                    callback.error("FILE_ERROR", "Video file not found")
                }
            } else {
                // 用户取消或录像失败
                callback.error("CANCELLED", "Video recording cancelled")
            }

            // 清理
            currentCallback = null
            currentVideoUri = null
            currentVideoPath = null
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

            if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                // 权限授予成功
                callback.success(mapOf("granted" to true))
            } else {
                // 权限被拒绝
                callback.error("PERMISSION_DENIED", "Camera or audio permission denied")
            }

            currentCallback = null
            return true
        }
        return false
    }
}
