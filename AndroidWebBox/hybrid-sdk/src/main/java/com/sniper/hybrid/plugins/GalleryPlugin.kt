package com.sniper.hybrid.plugins

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.MediaStore
import android.util.Log
import androidx.core.content.ContextCompat
import com.sniper.hybrid.plugin.BasePlugin
import com.sniper.hybrid.plugin.PluginCallback
import org.json.JSONObject

/**
 * 相册插件
 * 支持选择图片/视频
 */
class GalleryPlugin : BasePlugin() {

    companion object {
        private const val REQUEST_CODE_PICK = 2001
        private const val REQUEST_CODE_PERMISSION = 2002
    }

    private var currentCallback: PluginCallback? = null
    private var currentConfig: GalleryConfig? = null

    private data class GalleryConfig(
        val multiple: Boolean = false,
        val maxCount: Int = 1,
        val mediaType: String = "image" // image, video, all
    )

    override fun pluginName() = "gallery"

    override fun exec(action: String, params: JSONObject, callback: PluginCallback) {
        if (!ensureAttached()) {
            callback.error("PLUGIN_ERROR", "Plugin not attached")
            return
        }

        when (action) {
            "pick" -> pick(params, callback)
            else -> callback.error("UNKNOWN_ACTION", "Unknown action: $action")
        }
    }

    /**
     * 选择图片/视频
     */
    private fun pick(params: JSONObject, callback: PluginCallback) {
        val context = requireContext().getContext()

        // 解析参数
        val config = GalleryConfig(
            multiple = optBoolean(params, "multiple", false),
            maxCount = optInt(params, "max_count", 1),
            mediaType = optString(params, "media_type", "image")
        )

        // 验证参数
        if (config.multiple && config.maxCount < 1) {
            callback.error("INVALID_PARAMS", "max_count must be at least 1 when multiple is true")
            return
        }

        if (!config.multiple && config.maxCount > 1) {
            callback.error("INVALID_PARAMS", "max_count must be 1 when multiple is false")
            return
        }

        // 检查权限（Android 13+需要READ_MEDIA_IMAGES或READ_MEDIA_VIDEO）
        if (!checkStoragePermission(config.mediaType)) {
            requestStoragePermission(config.mediaType)
            currentCallback = callback
            currentConfig = config
            return
        }

        currentCallback = callback
        currentConfig = config

        // 创建选择Intent
        val intent = createPickIntent(config)

        try {
            requireContext().startActivityForResult(
                Intent.createChooser(intent, "Select Media"),
                REQUEST_CODE_PICK
            )
        } catch (e: Exception) {
            Log.e(pluginName(), "Error opening gallery", e)
            callback.error("GALLERY_ERROR", e.message)
            currentCallback = null
            currentConfig = null
        }
    }

    /**
     * 创建选择Intent
     */
    private fun createPickIntent(config: GalleryConfig): Intent {
        val intent = if (config.multiple) {
            Intent(Intent.ACTION_GET_CONTENT).apply {
                putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            }
        } else {
            Intent(Intent.ACTION_PICK)
        }

        // 设置MIME类型
        when (config.mediaType) {
            "image" -> intent.type = "image/*"
            "video" -> intent.type = "video/*"
            "all" -> intent.type = "*/*"
            else -> intent.type = "image/*"
        }

        intent.addCategory(Intent.CATEGORY_OPENABLE)
        return intent
    }

    /**
     * 检查存储权限
     */
    private fun checkStoragePermission(mediaType: String): Boolean {
        val context = requireContext().getContext()

        // Android 13+使用新权限模型
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            when (mediaType) {
                "image" -> return ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.READ_MEDIA_IMAGES
                ) == PackageManager.PERMISSION_GRANTED
                "video" -> return ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.READ_MEDIA_VIDEO
                ) == PackageManager.PERMISSION_GRANTED
                "all" -> {
                    return ContextCompat.checkSelfPermission(
                        context,
                        Manifest.permission.READ_MEDIA_IMAGES
                    ) == PackageManager.PERMISSION_GRANTED &&
                            ContextCompat.checkSelfPermission(
                                context,
                                Manifest.permission.READ_MEDIA_VIDEO
                            ) == PackageManager.PERMISSION_GRANTED
                }
            }
        }

        // Android 12及以下使用旧权限
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.READ_EXTERNAL_STORAGE
        ) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * 请求存储权限
     */
    private fun requestStoragePermission(mediaType: String) {
        val permissions = mutableListOf<String>()

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            when (mediaType) {
                "image" -> permissions.add(Manifest.permission.READ_MEDIA_IMAGES)
                "video" -> permissions.add(Manifest.permission.READ_MEDIA_VIDEO)
                "all" -> {
                    permissions.add(Manifest.permission.READ_MEDIA_IMAGES)
                    permissions.add(Manifest.permission.READ_MEDIA_VIDEO)
                }
            }
        } else {
            permissions.add(Manifest.permission.READ_EXTERNAL_STORAGE)
        }

        requireContext().requestPermissions(permissions.toTypedArray(), REQUEST_CODE_PERMISSION)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == REQUEST_CODE_PICK) {
            val callback = currentCallback ?: return false
            val config = currentConfig ?: return false

            if (resultCode == android.app.Activity.RESULT_OK) {
                val results = mutableListOf<Map<String, String>>()

                // 处理选择结果
                data?.let { intent ->
                    // 处理多个选择
                    intent.clipData?.let { clipData ->
                        for (i in 0 until clipData.itemCount) {
                            clipData.getItemAt(i)?.uri?.let { uri ->
                                results.add(mapOf(
                                    "uri" to uri.toString(),
                                    "path" to getRealPathFromURI(uri)
                                ))
                            }
                        }
                    }

                    // 处理单个选择
                    if (results.isEmpty()) {
                        intent.data?.let { uri ->
                            results.add(mapOf(
                                "uri" to uri.toString(),
                                "path" to getRealPathFromURI(uri)
                            ))
                        }
                    }
                }

                // 检查数量限制
                if (config.multiple && config.maxCount < results.size) {
                    callback.error("TOO_MANY_SELECTED", "Maximum ${config.maxCount} items allowed")
                } else if (results.isNotEmpty()) {
                    val response = if (config.multiple) {
                        mapOf("files" to results)
                    } else {
                        results.first()
                    }
                    callback.success(response)
                } else {
                    callback.error("NO_SELECTION", "No media selected")
                }
            } else {
                callback.error("CANCELLED", "Gallery selection cancelled")
            }

            currentCallback = null
            currentConfig = null
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
            val config = currentConfig

            if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                // 权限授予成功
                if (config != null) {
                    // 重新触发选择
                    pick(JSONObject().apply {
                        put("multiple", config.multiple)
                        put("max_count", config.maxCount)
                        put("media_type", config.mediaType)
                    }, callback)
                }
            } else {
                callback.error("PERMISSION_DENIED", "Storage permission denied")
            }

            currentCallback = null
            currentConfig = null
            return true
        }
        return false
    }

    /**
     * 获取URI对应的真实路径
     */
    private fun getRealPathFromURI(uri: Uri): String {
        var result = uri.toString()

        try {
            val context = requireContext().getContext()
            val projection = arrayOf(MediaStore.Images.Media.DATA)
            context.contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val columnIndex = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATA)
                    if (columnIndex >= 0) {
                        result = cursor.getString(columnIndex) ?: result
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(pluginName(), "Error getting real path from URI", e)
        }

        return result
    }
}
