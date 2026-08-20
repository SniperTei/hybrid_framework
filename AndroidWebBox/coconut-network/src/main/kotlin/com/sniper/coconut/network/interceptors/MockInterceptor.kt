package com.sniper.coconut.network.interceptors

import com.sniper.coconut.network.HttpMethod
import com.sniper.coconut.network.HttpRequest
import com.sniper.coconut.network.HttpResponse
import com.sniper.coconut.network.utils.Logger
import kotlinx.serialization.json.JsonElement

private const val TAG = "MockInterceptor"

/**
 * Mock 规则
 * url 精确匹配；以 '*' 结尾 = 前缀匹配（显式声明，避免误命中）
 */
data class MockRule(
    /** 匹配的 URL（相对或绝对均可，与 request.url 按字符串比对）；以 '*' 结尾 = 前缀匹配 */
    val url: String,
    /** 匹配的 HTTP 方法；null = 任意方法 */
    val method: HttpMethod? = null,
    /** mock 的 HTTP 状态码，默认 200 */
    val httpStatus: Int? = null,
    /** mock 的业务码，默认 '000000' */
    val code: String? = null,
    /** mock 的消息 */
    val msg: String? = null,
    /** mock 的数据 */
    val data: JsonElement? = null,
    /** 模拟耗时（毫秒），用于测试慢网络 */
    val delayMs: Long? = null,
)

/**
 * Mock 结果载体（拦截器命中后挂到 request.mockResponse，由 Call 短路消费）
 */
class MockResult(
    var httpStatus: Int = 200,
    var code: String = "000000",
    var msg: String = "mock",
    var data: JsonElement? = null,
    var delayMs: Long = 0,
)

/**
 * Mock 拦截器
 * 开发调试用：命中规则时给 request 打 mock 标记，Call.execute 看到标记直接短路，不进 adapter
 *
 * 用法：
 *   val mock = MockInterceptor()
 *   mock.addRule(MockRule(url = "/api/user", method = HttpMethod.GET, data = buildJsonObject { put("name", "test") }))
 *   mock.addRule(MockRule(url = "/api/login*", httpStatus = 500, code = "500000", msg = "mock fail"))
 *   client.addInterceptor(mock)
 *
 * 注意：mock 短路发生在 UrlGuard 之前（mock 请求不出网），且生产包不建议注册。
 */
class MockInterceptor : RequestInterceptor {
    private val rules = mutableListOf<MockRule>()

    /** 注册 Mock 规则（链式） */
    fun addRule(rule: MockRule): MockInterceptor {
        rules.add(rule)
        return this
    }

    /** 清除所有 Mock 规则 */
    fun clearAll() {
        rules.clear()
    }

    override suspend fun onRequest(request: HttpRequest): HttpRequest {
        val rule = match(request) ?: return request

        Logger.i(TAG, "Mock hit: ${rule.method ?: "*"} ${rule.url}")

        request.enableMock = true
        request.mockResponse = MockResult(
            httpStatus = rule.httpStatus ?: 200,
            code = rule.code ?: "000000",
            msg = rule.msg ?: "mock",
            data = rule.data,
            delayMs = rule.delayMs ?: 0,
        )
        return request
    }

    override suspend fun onResponse(response: HttpResponse): HttpResponse = response

    /** 匹配规则：URL 精确 / '*' 前缀 + 方法校验（null = 任意） */
    private fun match(request: HttpRequest): MockRule? {
        val methodStr = request.method.name.uppercase()
        for (rule in rules) {
            if (rule.method != null && rule.method.name.uppercase() != methodStr) {
                continue
            }
            val pattern = rule.url
            if (pattern.endsWith("*")) {
                if (request.url.startsWith(pattern.substring(0, pattern.length - 1))) {
                    return rule
                }
            } else if (request.url == pattern) {
                return rule
            }
        }
        return null
    }
}
