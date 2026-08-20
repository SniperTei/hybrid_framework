package com.sniper.coconut.network.adapter

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonPrimitive
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URI

/**
 * 基于 JDK HttpURLConnection 的默认 Adapter 实现
 * 零第三方依赖；OkHttp 用户可换用 OkHttpAdapter
 */
class HttpURLConnectionAdapter : IHttpAdapter {

    override suspend fun sendRequest(request: AdapterRequest): AdapterResponse {
        return withContext(Dispatchers.IO) { execute(request) }
    }

    private fun execute(request: AdapterRequest): AdapterResponse {
        val conn = URI.create(request.url).toURL().openConnection() as HttpURLConnection
        try {
            conn.requestMethod = request.method
            conn.connectTimeout = request.connectTimeout
            conn.readTimeout = request.readTimeout
            conn.instanceFollowRedirects = true

            for ((key, value) in request.headers) {
                conn.setRequestProperty(key, value)
            }

            val hasBody = request.multiFormDataList.isNotEmpty() || request.body != null
            if (hasBody && request.method != "GET") {
                conn.doOutput = true
                val (payload, contentType) = buildPayload(request)
                if (!request.headers.containsKey("Content-Type")) {
                    conn.setRequestProperty("Content-Type", contentType)
                }
                conn.outputStream.use { it.write(payload) }
            }

            val status = conn.responseCode
            val headers = mutableMapOf<String, String>()
            for ((key, values) in conn.headerFields) {
                if (key != null && values != null && values.isNotEmpty()) {
                    headers[key] = values.joinToString(",")
                }
            }

            val bodyBytes = try {
                (if (status >= 400) conn.errorStream else conn.inputStream)?.use { it.readBytes() }
            } catch (e: Exception) {
                null
            }
            val contentTypeHeader = conn.getHeaderField("Content-Type") ?: ""
            val body = parseBody(contentTypeHeader, bodyBytes)

            return AdapterResponse(status, headers, body)
        } finally {
            conn.disconnect()
        }
    }

    /** 构造请求负载：multipart 或 JSON body → (bytes, contentType) */
    private fun buildPayload(request: AdapterRequest): Pair<ByteArray, String> {
        if (request.multiFormDataList.isNotEmpty()) {
            val boundary = "coconut-${System.nanoTime()}"
            val bytes = buildMultipart(request.multiFormDataList, boundary)
            return bytes to "multipart/form-data; boundary=$boundary"
        }
        val body = request.body
        return (body?.toString() ?: "").toByteArray(Charsets.UTF_8) to request.contentType
    }

    private fun buildMultipart(items: List<FormDataItem>, boundary: String): ByteArray {
        val out = ByteArrayOutputStream()
        for (item in items) {
            out.write("--$boundary\r\n".toByteArray(Charsets.UTF_8))
            val filename = item.remoteFileName ?: "file"
            out.write(
                "Content-Disposition: form-data; name=\"${item.name}\"; filename=\"$filename\"\r\n"
                    .toByteArray(Charsets.UTF_8)
            )
            out.write("Content-Type: ${item.contentType}\r\n\r\n".toByteArray(Charsets.UTF_8))
            out.write(item.data)
            out.write("\r\n".toByteArray(Charsets.UTF_8))
        }
        out.write("--$boundary--\r\n".toByteArray(Charsets.UTF_8))
        return out.toByteArray()
    }

    /** JSON 响应解析为 JsonElement；非 JSON 包装为字符串基元（Adapter 契约） */
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
}
