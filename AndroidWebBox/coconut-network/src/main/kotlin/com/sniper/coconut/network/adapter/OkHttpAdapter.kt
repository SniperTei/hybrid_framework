package com.sniper.coconut.network.adapter

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonPrimitive
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

/**
 * 基于 OkHttp 的可选 Adapter 实现
 *
 * okhttp 为 compileOnly 依赖 — 模块不强制传递；想用本 Adapter 的宿主自行添加：
 *   implementation("com.squareup.okhttp3:okhttp:4.12.0")
 * （类只有被实例化才会加载 okhttp，不加依赖的宿主不受影响）
 */
class OkHttpAdapter(
    private val client: OkHttpClient = defaultClient(),
) : IHttpAdapter {

    override suspend fun sendRequest(request: AdapterRequest): AdapterResponse {
        return withContext(Dispatchers.IO) { execute(request) }
    }

    private fun execute(request: AdapterRequest): AdapterResponse {
        // GET 不携带 body（OkHttp 会抛 IllegalArgumentException）
        val body = if (request.method == "GET") null else buildRequestBody(request)
        val builder = Request.Builder()
            .url(request.url)
            .method(request.method, body)

        for ((key, value) in request.headers) {
            builder.header(key, value)
        }

        // 按请求的超时派生 client（newBuilder 共享连接池/线程池，开销极小）
        val effective = client.newBuilder()
            .connectTimeout(request.connectTimeout.toLong(), TimeUnit.MILLISECONDS)
            .readTimeout(request.readTimeout.toLong(), TimeUnit.MILLISECONDS)
            .build()

        effective.newCall(builder.build()).execute().use { response ->
            // okhttp Headers 迭代产出 (name, value) 对；重名 header 用逗号合并
            val headers = mutableMapOf<String, String>()
            for ((name, value) in response.headers) {
                val existing = headers[name]
                headers[name] = if (existing == null) value else "$existing,$value"
            }
            val contentType = response.header("Content-Type") ?: ""
            val bodyBytes = response.body?.bytes()

            // bytes 模式：原始字节直通，不解析为 JsonElement
            if (request.responseType == HttpResponseType.BYTES) {
                return AdapterResponse(response.code, headers, null, rawBody = bodyBytes)
            }

            return AdapterResponse(response.code, headers, parseBody(contentType, bodyBytes))
        }
    }

    private fun buildRequestBody(request: AdapterRequest): RequestBody? {
        if (request.multiFormDataList.isNotEmpty()) {
            val multipart = MultipartBody.Builder()
                .setType(MultipartBody.FORM)
            for (item in request.multiFormDataList) {
                multipart.addFormDataPart(
                    item.name,
                    item.remoteFileName ?: "file",
                    item.data.toRequestBody(item.contentType.toMediaType()),
                )
            }
            return multipart.build()
        }
        val body = request.body ?: return null
        return body.toString().toRequestBody(request.contentType.toMediaType())
    }

    private fun parseBody(contentType: String, bytes: ByteArray?): JsonElement? {
        if (bytes == null) {
            return null
        }
        val text = String(bytes, Charsets.UTF_8)
        return if (contentType.contains("json", ignoreCase = true)) {
            try {
                Json.parseToJsonElement(text)
            } catch (e: Exception) {
                JsonPrimitive(text)
            }
        } else {
            JsonPrimitive(text)
        }
    }

    companion object {
        private fun defaultClient(): OkHttpClient {
            return OkHttpClient.Builder().build()
        }
    }
}
