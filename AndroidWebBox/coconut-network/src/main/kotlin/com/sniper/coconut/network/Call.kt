package com.sniper.coconut.network

import com.sniper.coconut.network.adapter.AdapterRequest
import com.sniper.coconut.network.adapter.AdapterResponse
import com.sniper.coconut.network.adapter.HttpResponseType
import com.sniper.coconut.network.adapter.IHttpAdapter
import com.sniper.coconut.network.guard.UrlGuard
import com.sniper.coconut.network.interceptors.MockResult
import com.sniper.coconut.network.interceptors.RequestInterceptor
import com.sniper.coconut.network.utils.Logger
import kotlinx.coroutines.delay
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import java.net.URLEncoder

private const val TAG = "HttpClient"

/**
 * Call — HTTP 请求执行器
 * 持有一次请求的全部上下文（request + config + adapter + interceptors）
 *
 * 执行顺序：
 *   1. mock 短路检查（构造时手动 enableMocking 的）
 *   2. 请求拦截器链（正序）
 *   3. mock 短路检查（拦截器打标的，如 MockInterceptor）
 *   4. 拼接完整 URL
 *   5. UrlGuard 出站校验（mock 已在前面短路，不出网不受守卫约束）
 *   6. adapter 派发（带重试）
 *   7. 响应拦截器链（逆序）
 */
class Call internal constructor(
    private val request: HttpRequest,
    private val config: HttpConfig,
    private val adapter: IHttpAdapter,
    private val interceptors: List<RequestInterceptor>,
) {
    /** 执行请求 */
    suspend fun execute(): HttpResponse {
        val startTime = System.currentTimeMillis()

        var currentRequest = request

        // Mock 短路（构造时手动设置）
        if (currentRequest.enableMock && currentRequest.mockResponse != null) {
            return shortCircuitMock(currentRequest.mockResponse!!, startTime)
        }

        // 执行请求拦截器链（正序）
        for (interceptor in interceptors) {
            currentRequest = interceptor.onRequest(currentRequest)
        }

        // 再次 mock 短路（拦截器可能打标，如 MockInterceptor）
        if (currentRequest.enableMock && currentRequest.mockResponse != null) {
            return shortCircuitMock(currentRequest.mockResponse!!, startTime)
        }

        // 拼接完整 URL
        val fullUrl = buildFullUrl(currentRequest)

        // 获取超时/重试配置
        val connectTimeout =
            if (currentRequest.connectTimeout > 0) currentRequest.connectTimeout else config.connectTimeout
        val readTimeout =
            if (currentRequest.readTimeout > 0) currentRequest.readTimeout else config.readTimeout
        val retryCount =
            if (currentRequest.retryCount >= 0) currentRequest.retryCount else config.retryCount

        // 合并公共 headers：config 公共 < request 单次（单次优先）
        val mergedHeaders = LinkedHashMap<String, String>()
        mergedHeaders.putAll(config.headers)
        mergedHeaders.putAll(currentRequest.headers)

        // 构建 AdapterRequest
        val adapterRequest = AdapterRequest(
            method = currentRequest.method.name,
            url = fullUrl,
            headers = mergedHeaders,
            body = currentRequest.body,
            contentType = currentRequest.contentType,
            connectTimeout = connectTimeout,
            readTimeout = readTimeout,
            multiFormDataList = currentRequest.multiFormDataList,
            responseType = currentRequest.responseType,
        )

        var response: HttpResponse

        // 出站守卫（scheme 白名单 + allowedDomains 后缀匹配）
        val guardResult = UrlGuard.validate(fullUrl, config.allowedDomains)
        if (!guardResult.allowed) {
            Logger.w(TAG, "Blocked by UrlGuard: $fullUrl (${guardResult.reason})")
            response = HttpResponse.error(
                HttpErrorCode.URL_BLOCKED.code.toString(), 0,
                "请求被出站守卫拦截: ${guardResult.reason}"
            )
        } else {
            // 带重试的请求
            response = executeWithRetry(retryCount, adapterRequest, currentRequest.responseType)
        }

        response.costTime = System.currentTimeMillis() - startTime

        // 执行响应拦截器链（逆序）
        var baseResponse = response
        for (i in interceptors.indices.reversed()) {
            baseResponse = interceptors[i].onResponse(baseResponse)
        }

        return baseResponse
    }

    /** 带重试的 adapter 派发：全部失败后映射为网络/超时/SSL 错误 */
    private suspend fun executeWithRetry(
        retryCount: Int,
        adapterRequest: AdapterRequest,
        responseType: HttpResponseType,
    ): HttpResponse {
        var lastError: Throwable? = null
        for (attempt in 0..retryCount) {
            try {
                return parseResponse(adapter.sendRequest(adapterRequest), responseType)
            } catch (err: Throwable) {
                lastError = err
                if (attempt < retryCount) {
                    delay(config.retryDelay.toLong())
                }
            }
        }
        return handleError(lastError ?: IllegalStateException("unknown error"))
    }

    /** Mock 短路：mockResponse 是 MockResult 则按其字段构造，否则视为纯业务数据 */
    private suspend fun shortCircuitMock(mock: Any, startTime: Long): HttpResponse {
        var httpStatus = 200
        var code = "000000"
        var msg = "mock"
        var data: JsonElement? = null
        var delayMs: Long = 0

        if (mock is MockResult) {
            httpStatus = mock.httpStatus
            code = mock.code
            msg = mock.msg
            data = mock.data
            delayMs = mock.delayMs
        } else if (mock is JsonElement) {
            data = mock
        }

        if (delayMs > 0) {
            delay(delayMs)
        }

        val resp = HttpResponse()
        resp.httpStatus = httpStatus
        resp.statusCode = httpStatus
        resp.code = code
        resp.msg = msg
        resp.data = data
        resp.costTime = System.currentTimeMillis() - startTime
        return resp
    }

    /** 拼接完整 URL（与 ArkTS encodeURIComponent 对齐：空格编码为 %20 而非 form 的 +） */
    private fun buildFullUrl(request: HttpRequest): String {
        var url = config.baseUrl + request.url
        if (request.params.isNotEmpty()) {
            val parts = request.params.map { (key, value) ->
                "${enc(key)}=${enc(value)}"
            }
            url += (if (url.contains('?')) "&" else "?") + parts.joinToString("&")
        }
        return url
    }

    private fun enc(s: String): String =
        URLEncoder.encode(s, "UTF-8").replace("+", "%20")

    /** 解析 AdapterResponse → HttpResponse */
    private fun parseResponse(adapterResp: AdapterResponse, responseType: HttpResponseType): HttpResponse {
        val httpStatus = adapterResp.httpStatus

        // HTTP 错误
        if (httpStatus >= 400) {
            return HttpResponse.error(httpStatus.toString(), httpStatus, getHttpErrorMessage(httpStatus))
        }

        // bytes 模式：原始字节直通，不做 envelope 嗅探（内容恰为 envelope 形状也直通）
        if (responseType == HttpResponseType.BYTES) {
            val resp = HttpResponse.success(httpStatus, null)
            resp.headers = adapterResp.headers
            resp.rawData = adapterResp.rawBody
            return resp
        }

        // 解析业务响应：body 是 object 且含 "code" 字段才视为 envelope { code, statusCode, msg, data, timestamp }，
        // 否则按非 envelope 直通（如 manifest.json 等 2xx JSON body，补默认成功码）
        val responseBody = adapterResp.body
        if (responseBody is JsonObject && responseBody.containsKey("code")) {
            val code = (responseBody["code"] as? JsonPrimitive)?.contentOrNull ?: ""
            val statusCode = (responseBody["statusCode"] as? JsonPrimitive)?.contentOrNull?.toIntOrNull()
                ?: httpStatus
            val msg = (responseBody["msg"] as? JsonPrimitive)?.contentOrNull ?: ""
            val data = responseBody["data"].orNullIfJsonNull()
            val timestamp = (responseBody["timestamp"] as? JsonPrimitive)?.contentOrNull ?: ""

            val resp = HttpResponse.success(httpStatus, data, msg)
            resp.code = code
            resp.statusCode = statusCode
            resp.timestamp = timestamp
            resp.headers = adapterResp.headers
            return resp
        }

        // 非 envelope 响应：body 直通，补默认成功码
        val resp = HttpResponse.success(httpStatus, responseBody.orNullIfJsonNull())
        resp.headers = adapterResp.headers
        return resp
    }

    /** 处理请求异常 */
    private fun handleError(error: Throwable): HttpResponse {
        val msg = error.message ?: "Unknown error"
        val lower = msg.lowercase()
        if (lower.contains("timeout") || lower.contains("timed out")) {
            return HttpResponse.error(
                HttpErrorCode.TIMEOUT_ERROR.code.toString(), 0, "请求超时: $msg"
            )
        }
        if (lower.contains("ssl") || lower.contains("certificate")) {
            return HttpResponse.error(
                HttpErrorCode.SSL_ERROR.code.toString(), 0, "SSL错误: $msg"
            )
        }
        return HttpResponse.error(
            HttpErrorCode.NETWORK_ERROR.code.toString(), 0, "网络错误: $msg"
        )
    }

    /** 获取 HTTP 错误信息 */
    private fun getHttpErrorMessage(status: Int): String {
        return when (status) {
            400 -> "请求参数错误"
            401 -> "未授权"
            403 -> "禁止访问"
            404 -> "资源不存在"
            405 -> "请求方法不允许"
            500 -> "服务器内部错误"
            502 -> "网关错误"
            503 -> "服务不可用"
            else -> "HTTP错误 $status"
        }
    }
}
