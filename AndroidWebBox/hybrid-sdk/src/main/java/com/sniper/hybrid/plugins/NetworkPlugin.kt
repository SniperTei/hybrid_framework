package com.sniper.hybrid.plugins

import android.content.Context
import android.util.Log
import com.sniper.hybrid.plugin.BasePlugin
import com.sniper.hybrid.plugin.PluginCallback
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.util.concurrent.TimeUnit

/**
 * 网络请求插件
 * 支持GET/POST/PUT/DELETE/PATCH以及文件上传/下载
 */
class NetworkPlugin : BasePlugin() {

    companion object {
        private const val TAG = "NetworkPlugin"
        private const val DEFAULT_PROGRESS_INTERVAL = 100 // 进度回调间隔(ms)
    }

    private var config: NetworkConfig = NetworkConfig.default()
    private var okHttpClient: OkHttpClient? = null
    private val scope = CoroutineScope(Dispatchers.IO)

    /**
     * 设置网络配置
     */
    fun setConfig(config: NetworkConfig) {
        this.config = config
        initOkHttp()
    }

    /**
     * 初始化OkHttpClient
     */
    private fun initOkHttp() {
        val builder = OkHttpClient.Builder()

        // 设置超时
        builder.connectTimeout(config.connectTimeout, TimeUnit.MILLISECONDS)
            .readTimeout(config.readTimeout, TimeUnit.MILLISECONDS)
            .writeTimeout(config.writeTimeout, TimeUnit.MILLISECONDS)

        // 添加拦截器
        config.requestInterceptors.forEach { builder.addInterceptor(it) }
        config.responseInterceptors.forEach { builder.addInterceptor(it) }

        // 添加日志拦截器（开发模式）
        if (pluginContext?.getContext()?.let { isDebugMode(it) } == true) {
            builder.addInterceptor(createLoggingInterceptor())
        }

        // 重试拦截器
        if (config.retryCount > 0) {
            builder.addInterceptor(createRetryInterceptor())
        }

        // 缓存配置
        if (config.enableCache && config.cacheDir != null) {
            try {
                val cacheDir = File(config.cacheDir)
                if (!cacheDir.exists()) {
                    cacheDir.mkdirs()
                }
                val cache = Cache(cacheDir, config.cacheSize)
                builder.cache(cache)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to setup cache", e)
            }
        }

        okHttpClient = builder.build()
    }

    /**
     * 检查是否是调试模式
     */
    private fun isDebugMode(context: Context): Boolean {
        return (context.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
    }

    /**
     * 创建日志拦截器
     */
    private fun createLoggingInterceptor(): Interceptor {
        return Interceptor { chain ->
            val request = chain.request()
            val startNs = System.nanoTime()

            Log.d(TAG, "Sending request: ${request.url}")
            Log.d(TAG, "Headers: ${request.headers}")

            val response = chain.proceed(request)

            val tookMs = (System.nanoTime() - startNs) / 1_000_000
            Log.d(TAG, "Received response in ${tookMs}ms: ${response.code}")

            response
        }
    }

    /**
     * 创建重试拦截器
     */
    private fun createRetryInterceptor(): Interceptor {
        return Interceptor { chain ->
            val request = chain.request()
            var response = chain.proceed(request)
            var retryCount = 0

            while (!response.isSuccessful && retryCount < config.retryCount) {
                retryCount++
                Log.w(TAG, "Request failed, retrying ($retryCount/${config.retryCount})")
                response.close()
                response = chain.proceed(request)
            }

            response
        }
    }

    override fun pluginName() = "http"

    override fun onAttach(context: com.sniper.hybrid.plugin.PluginContext) {
        super.onAttach(context)
        initOkHttp()
    }

    override fun exec(action: String, params: JSONObject, callback: PluginCallback) {
        if (!ensureAttached()) {
            callback.error("PLUGIN_ERROR", "Plugin not attached")
            return
        }

        // 延迟初始化（如果还没有设置配置）
        if (okHttpClient == null) {
            initOkHttp()
        }

        when (action) {
            "get", "GET" -> executeRequest("GET", params, callback)
            "post", "POST" -> executeRequest("POST", params, callback)
            "put", "PUT" -> executeRequest("PUT", params, callback)
            "delete", "DELETE" -> executeRequest("DELETE", params, callback)
            "patch", "PATCH" -> executeRequest("PATCH", params, callback)
            "upload" -> uploadFile(params, callback)
            "download" -> downloadFile(params, callback)
            "setConfig" -> setConfig(params, callback)
            else -> callback.error("UNKNOWN_ACTION", "Unknown action: $action")
        }
    }

    /**
     * 执行HTTP请求
     */
    private fun executeRequest(
        method: String,
        params: JSONObject,
        callback: PluginCallback
    ) {
        scope.launch {
            try {
                val url = buildUrl(params.optString("url", ""))
                val headers = parseHeaders(params.optJSONObject("headers"))
                val body = parseBody(params, method)
                val timeout = optInt(params, "timeout", 0).takeIf { it > 0 }

                val requestBuilder = Request.Builder().url(url)

                // 添加自定义请求头
                headers.forEach { (key, value) ->
                    requestBuilder.addHeader(key, value)
                }

                // 添加默认请求头
                config.defaultHeaders.forEach { (key, value) ->
                    if (!headers.containsKey(key)) {
                        requestBuilder.addHeader(key, value)
                    }
                }

                // 设置请求方法和body
                when (method.uppercase()) {
                    "GET" -> requestBuilder.get()
                    "POST" -> requestBuilder.post(body ?: createEmptyBody())
                    "PUT" -> requestBuilder.put(body ?: createEmptyBody())
                    "DELETE" -> {
                        if (body != null) {
                            requestBuilder.delete(body)
                        } else {
                            requestBuilder.delete()
                        }
                    }
                    "PATCH" -> requestBuilder.patch(body ?: createEmptyBody())
                }

                val request = requestBuilder.build()

                // 创建自定义超时的客户端
                val client = if (timeout != null && timeout > 0) {
                    okHttpClient?.newBuilder()
                        ?.readTimeout(timeout.toLong(), TimeUnit.MILLISECONDS)
                        ?.build()
                } else okHttpClient

                // 执行请求
                val response = client?.newCall(request)?.execute()

                if (response != null) {
                    handleResponse(response, callback)
                } else {
                    callback.error("NETWORK_ERROR", "Failed to execute request")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Request failed", e)
                callback.error("REQUEST_ERROR", e.message ?: "Unknown error")
            }
        }
    }

    /**
     * 处理响应
     */
    private fun handleResponse(response: Response, callback: PluginCallback) {
        val responseBody = response.body
        val responseText = responseBody?.string() ?: ""
        val responseCode = response.code

        // 构建响应头Map
        val headers = mutableMapOf<String, String>()
        response.headers.forEach { (name, value) ->
            headers[name] = value
        }

        val result = mutableMapOf(
            "statusCode" to responseCode,
            "headers" to headers,
            "data" to responseText
        )

        if (response.isSuccessful) {
            callback.success(result)
        } else {
            callback.error("HTTP_ERROR_$responseCode", responseText, responseCode, result)
        }
    }

    /**
     * 构建完整URL
     */
    private fun buildUrl(url: String): String {
        return when {
            url.startsWith("http://") || url.startsWith("https://") -> url
            config.baseUrl.isNotEmpty() -> {
                val baseUrl = config.baseUrl.trimEnd('/')
                val path = url.trimStart('/')
                "$baseUrl/$path"
            }
            else -> url
        }
    }

    /**
     * 解析请求头
     */
    private fun parseHeaders(headersJson: JSONObject?): Map<String, String> {
        val headers = mutableMapOf<String, String>()
        if (headersJson != null) {
            headersJson.keys().forEach { key ->
                headers[key] = headersJson.optString(key)
            }
        }
        return headers
    }

    /**
     * 解析请求体
     */
    private fun parseBody(params: JSONObject, method: String): RequestBody? {
        if (method == "GET") return null

        // 检查是否是文件上传
        if (params.has("file")) {
            return null // 文件上传在uploadFile方法中处理
        }

        val data = params.opt("data")
        val contentType = params.optString("contentType", "application/json")

        return when (data) {
            is String -> {
                // 字符串数据
                data.toRequestBody(contentType.toMediaTypeOrNull())
            }
            is JSONObject -> {
                // JSON对象
                data.toString().toRequestBody(contentType.toMediaTypeOrNull())
            }
            is org.json.JSONArray -> {
                // JSON数组
                data.toString().toRequestBody(contentType.toMediaTypeOrNull())
            }
            else -> {
                // Form数据
                val formBuilder = FormBody.Builder()
                params.keys().forEach { key ->
                    if (key !in listOf("url", "headers", "contentType", "timeout", "data")) {
                        formBuilder.add(key, params.optString(key))
                    }
                }
                formBuilder.build()
            }
        }
    }

    /**
     * 上传文件
     */
    private fun uploadFile(params: JSONObject, callback: PluginCallback) {
        scope.launch {
            try {
                val url = buildUrl(params.optString("url"))
                val filePath = params.optString("file")
                val file = File(filePath)
                val name = params.optString("name", "file")
                val mimeType = params.optString("mimeType", "application/octet-stream")

                if (!file.exists()) {
                    callback.error("FILE_NOT_FOUND", "File not found: $filePath")
                    return@launch
                }

                // 构建multipart请求体
                val requestBody = MultipartBody.Builder()
                    .setType(MultipartBody.FORM)
                    .addFormDataPart(
                        name,
                        file.name,
                        file.asRequestBody(mimeType.toMediaTypeOrNull())
                    )

                // 添加额外表单字段
                params.keys().forEach { key ->
                    if (key !in listOf("url", "file", "name", "mimeType")) {
                        requestBody.addFormDataPart(key, params.optString(key))
                    }
                }

                val request = Request.Builder()
                    .url(url)
                    .post(requestBody.build())
                    .build()

                // 执行上传（带进度）
                val progressCallback = params.optBoolean("progress", false)
                if (progressCallback) {
                    uploadWithProgress(request, callback)
                } else {
                    val response = okHttpClient?.newCall(request)?.execute()
                    if (response != null) {
                        handleResponse(response, callback)
                    } else {
                        callback.error("UPLOAD_ERROR", "Failed to upload file")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Upload failed", e)
                callback.error("UPLOAD_ERROR", e.message ?: "Unknown error")
            }
        }
    }

    /**
     * 带进度的上传
     */
    private suspend fun uploadWithProgress(
        request: Request,
        callback: PluginCallback
    ) {
        try {
            // 创建带进度监听的请求体
            val progressRequestBody = ProgressRequestBody(request.body!!, object : ProgressListener {
                override fun onProgress(bytesWritten: Long, contentLength: Long) {
                    if (contentLength > 0) {
                        val percent = (bytesWritten * 100 / contentLength).toInt()
                        callback.progress(percent)
                    }
                }
            })

            val progressRequest = request.newBuilder()
                .post(progressRequestBody)
                .build()

            val response = okHttpClient?.newCall(progressRequest)?.execute()
            if (response != null) {
                handleResponse(response, callback)
            } else {
                callback.error("UPLOAD_ERROR", "Failed to upload file")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Upload with progress failed", e)
            callback.error("UPLOAD_ERROR", e.message ?: "Unknown error")
        }
    }

    /**
     * 下载文件
     */
    private fun downloadFile(params: JSONObject, callback: PluginCallback) {
        scope.launch {
            try {
                val url = buildUrl(params.optString("url"))
                val savePath = params.optString("savePath")

                val request = Request.Builder()
                    .url(url)
                    .get()
                    .build()

                val response = okHttpClient?.newCall(request)?.execute()
                val responseBody = response?.body

                if (response != null && responseBody != null) {
                    val saveFile = File(savePath)
                    val parentDir = saveFile.parentFile
                    if (parentDir != null && !parentDir.exists()) {
                        parentDir.mkdirs()
                    }

                    // 保存文件
                    saveFile.outputStream().use { output ->
                        responseBody.byteStream().use { input ->
                            input.copyTo(output)
                        }
                    }

                    val result = mapOf(
                        "savedPath" to savePath,
                        "contentLength" to responseBody.contentLength(),
                        "contentType" to responseBody.contentType().toString()
                    )

                    callback.success(result)
                } else {
                    callback.error("DOWNLOAD_ERROR", "Failed to download file")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Download failed", e)
                callback.error("DOWNLOAD_ERROR", e.message ?: "Unknown error")
            }
        }
    }

    /**
     * 设置配置
     */
    private fun setConfig(params: JSONObject, callback: PluginCallback) {
        try {
            val baseUrl = params.optString("baseUrl", "")
            val connectTimeout = params.optLong("connectTimeout", 30_000)
            val readTimeout = params.optLong("readTimeout", 30_000)
            val writeTimeout = params.optLong("writeTimeout", 30_000)
            val enableCache = params.optBoolean("enableCache", false)
            val retryCount = params.optInt("retryCount", 0)

            val newConfig = NetworkConfig.Builder()
                .setBaseUrl(baseUrl)
                .setConnectTimeout(connectTimeout)
                .setReadTimeout(readTimeout)
                .setWriteTimeout(writeTimeout)
                .setEnableCache(enableCache)
                .setRetryCount(retryCount)
                .build()

            setConfig(newConfig)

            callback.success(mapOf("configured" to true))
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set config", e)
            callback.error("CONFIG_ERROR", e.message ?: "Unknown error")
        }
    }

    /**
     * 错误回调的辅助方法
     */
    private fun PluginCallback.error(code: String, message: String?, httpCode: Int, data: Map<String, Any?>) {
        val errorData = data.toMutableMap()
        errorData["error"] = mapOf(
            "code" to code,
            "message" to (message ?: code),
            "httpCode" to httpCode
        )
        this.success(errorData)
    }

    /**
     * 创建空请求体
     */
    private fun createEmptyBody(): RequestBody {
        return "".toRequestBody("application/json".toMediaTypeOrNull())
    }

    /**
     * 进度监听接口
     */
    interface ProgressListener {
        fun onProgress(bytesWritten: Long, contentLength: Long)
    }

    /**
     * 带进度监听的请求体
     */
    private class ProgressRequestBody(
        private val requestBody: RequestBody,
        private val listener: ProgressListener
    ) : RequestBody() {

        override fun contentType(): MediaType? = requestBody.contentType()

        override fun contentLength(): Long = requestBody.contentLength()

        override fun writeTo(sink: okio.BufferedSink) {
            val contentLength = contentLength()
            var bytesWritten = 0L

            // 将数据写入BufferedSink的包装
            val bufferedSink = okio.Buffer()
            requestBody.writeTo(bufferedSink)

            // 获取总字节数
            val totalBytes = bufferedSink.size

            // 将buffer内容写入目标sink，并报告进度
            val bufferArray = bufferedSink.readByteArray()
            val offset = 0L
            var remaining = bufferArray.size.toLong()

            while (remaining > 0) {
                val bytesToWrite = minOf(8192L, remaining)
                sink.write(bufferArray, offset.toInt() + (totalBytes - remaining).toInt(), bytesToWrite.toInt())
                bytesWritten += bytesToWrite
                remaining -= bytesToWrite
                listener.onProgress(bytesWritten, totalBytes)
            }

            sink.flush()
        }
    }
}
