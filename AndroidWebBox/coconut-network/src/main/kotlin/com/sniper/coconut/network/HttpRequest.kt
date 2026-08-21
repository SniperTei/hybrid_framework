package com.sniper.coconut.network

import com.sniper.coconut.network.adapter.FormDataItem
import com.sniper.coconut.network.adapter.HttpResponseType
import com.sniper.coconut.network.adapter.IHttpAdapter
import com.sniper.coconut.network.interceptors.RequestInterceptor
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

/** HTTP 方法枚举（不依赖任何平台网络 SDK） */
enum class HttpMethod {
    GET, POST, PUT, DELETE
}

/** 请求选项 */
data class RequestOptions(
    val method: HttpMethod? = null,
    val headers: Map<String, String>? = null,
    val params: Map<String, String>? = null,
    val body: JsonElement? = null,
    val tag: String? = null,
    val connectTimeout: Int? = null,
    val readTimeout: Int? = null,
    val multiFormDataList: List<FormDataItem>? = null,
    val responseType: HttpResponseType? = null,
)

/** HttpClient 上下文接口（避免循环依赖） */
interface HttpClientContext {
    fun getConfig(): HttpConfig
    fun getAdapter(): IHttpAdapter
    fun getInterceptors(): List<RequestInterceptor>
}

/**
 * HTTP 请求对象
 * 构造时传入 url + options，通过 buildCall() 创建执行器
 */
class HttpRequest(
    val url: String,
    options: RequestOptions? = null,
    private var context: HttpClientContext? = null,
) {
    /** HTTP 方法 */
    var method: HttpMethod = HttpMethod.GET

    /** 请求路径（相对 baseUrl） */
    var headers: MutableMap<String, String> = mutableMapOf()
        private set

    /** URL 查询参数 */
    var params: MutableMap<String, String> = mutableMapOf()
        private set

    /** 请求体 */
    var body: JsonElement? = null
        private set

    /** 内容类型 */
    var contentType: String = "application/json"

    /** 请求标签（用于日志和取消） */
    var tag: String = ""

    /** 文件上传表单数据 */
    var multiFormDataList: List<FormDataItem> = emptyList()

    /** 覆盖全局重试次数 */
    var retryCount: Int = -1

    /** 覆盖全局读取超时 */
    var readTimeout: Int = -1

    /** 覆盖全局连接超时 */
    var connectTimeout: Int = -1

    /** 响应模式（JSON 解析 / BYTES 原始字节直通） */
    var responseType: HttpResponseType = HttpResponseType.JSON

    /** 单请求启用 Mock（由 MockInterceptor 打标，或手动 enableMocking） */
    var enableMock: Boolean = false
        internal set

    /** Mock 响应（MockResult 实例，或直接给业务数据对象） */
    var mockResponse: Any? = null
        internal set

    init {
        if (options != null) {
            options.method?.let { method = it }
            options.headers?.let { headers.putAll(it) }
            options.params?.let {
                // POST/PUT → params 自动转 body；GET/DELETE → 保留为 URL 查询参数
                if (method == HttpMethod.POST || method == HttpMethod.PUT) {
                    body = JsonObject(it.mapValues { (_, v) -> JsonPrimitive(v) })
                } else {
                    params.putAll(it)
                }
            }
            options.body?.let { body = it }
            options.tag?.let { tag = it }
            options.connectTimeout?.let { connectTimeout = it }
            options.readTimeout?.let { readTimeout = it }
            options.responseType?.let { responseType = it }
            options.multiFormDataList?.let { multiFormDataList = it }
        }
    }

    /** 创建 Call 执行器 */
    fun buildCall(): Call {
        val ctx = context
            ?: throw IllegalStateException("HttpRequest 未绑定 HttpClient，请使用 HttpClient.newRequest() 创建请求")
        return Call(this, ctx.getConfig(), ctx.getAdapter(), ctx.getInterceptors())
    }

    // 链式调用
    fun setHeader(key: String, value: String): HttpRequest {
        headers[key] = value
        return this
    }

    fun setBody(body: JsonElement): HttpRequest {
        this.body = body
        return this
    }

    fun setTag(tag: String): HttpRequest {
        this.tag = tag
        return this
    }

    fun setTimeout(connectTimeout: Int, readTimeout: Int): HttpRequest {
        this.connectTimeout = connectTimeout
        this.readTimeout = readTimeout
        return this
    }

    /** 手动启用 mock（直接给业务数据；带状态码/业务码的 mock 请用 MockInterceptor.addRule） */
    fun enableMocking(mockData: Any?): HttpRequest {
        enableMock = true
        mockResponse = mockData
        return this
    }
}
