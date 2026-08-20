package com.sniper.coconut.network.interceptors

import com.sniper.coconut.network.HttpConfig
import com.sniper.coconut.network.HttpRequest
import com.sniper.coconut.network.HttpResponse
import com.sniper.coconut.network.utils.Logger
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

private const val TAG = "HttpClient"

/**
 * 日志拦截器
 * 记录请求和响应信息，敏感字段脱敏
 */
class LogInterceptor(config: HttpConfig? = null) : RequestInterceptor {
    private val sensitiveHeaders: Set<String> =
        (config?.sensitiveHeaders ?: listOf("Authorization", "Cookie"))
            .flatMap { listOf(it.lowercase(), it) }.toSet()

    private val sensitiveParams: Set<String> =
        (config?.sensitiveParams ?: listOf("password", "token", "secret"))
            .flatMap { listOf(it.lowercase(), it) }.toSet()

    override suspend fun onRequest(request: HttpRequest): HttpRequest {
        val maskedHeaders = maskHeaders(request.headers)
        val maskedParams = maskParams(request.params)
        val bodyStr = request.body?.let { maskBody(it) } ?: "null"

        Logger.i(TAG, "--> ${request.method} ${request.url}")
        Logger.i(TAG, "    Headers: $maskedHeaders")
        Logger.i(TAG, "    Params: $maskedParams")
        Logger.i(TAG, "    Body: $bodyStr")

        return request
    }

    override suspend fun onResponse(response: HttpResponse): HttpResponse {
        Logger.i(TAG, "<-- HTTP ${response.httpStatus} code=${response.code} cost=${response.costTime}ms")
        Logger.i(TAG, "    Msg: ${response.msg}")

        return response
    }

    /** 脱敏 Header */
    private fun maskHeaders(headers: Map<String, String>): String {
        val result = LinkedHashMap<String, String>()
        for ((key, value) in headers) {
            result[key] = if (key in sensitiveHeaders) "***" else value
        }
        return result.toString()
    }

    /** 脱敏查询参数 */
    private fun maskParams(params: Map<String, String>): String {
        val result = LinkedHashMap<String, String>()
        for ((key, value) in params) {
            result[key] = if (key in sensitiveParams) "***" else value
        }
        return result.toString()
    }

    /** 脱敏请求体 */
    private fun maskBody(body: JsonElement): String {
        return try {
            if (body is JsonObject) {
                val result = LinkedHashMap<String, JsonElement>()
                for ((key, value) in body) {
                    result[key] = if (key in sensitiveParams) JsonPrimitive("***") else value
                }
                result.toString()
            } else {
                body.toString()
            }
        } catch (e: Exception) {
            body.toString()
        }
    }
}
