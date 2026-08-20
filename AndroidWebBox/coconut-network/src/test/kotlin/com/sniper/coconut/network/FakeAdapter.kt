package com.sniper.coconut.network

import com.sniper.coconut.network.adapter.AdapterRequest
import com.sniper.coconut.network.adapter.AdapterResponse
import com.sniper.coconut.network.adapter.IHttpAdapter
import kotlinx.serialization.json.Json

/**
 * 测试用 Fake 传输层：可脚本化响应 / 前 N 次抛错
 */
class FakeAdapter : IHttpAdapter {
    /** 收到的所有请求（按顺序） */
    val requests = mutableListOf<AdapterRequest>()

    /** 成功时返回的响应 */
    var response: AdapterResponse = AdapterResponse(200, emptyMap(), null)

    /** 前 failFirstCount 次调用抛 failError（模拟瞬时故障测重试） */
    var failFirstCount: Int = 0
    var failError: Throwable? = null

    /** 总调用次数 */
    var sendCount: Int = 0
        private set

    override suspend fun sendRequest(request: AdapterRequest): AdapterResponse {
        requests.add(request)
        sendCount++
        if (failError != null && sendCount <= failFirstCount) {
            throw failError!!
        }
        return response
    }

    /** 设置 envelope 形式的成功响应 */
    fun envelopeResponse(httpStatus: Int, bodyJson: String) {
        response = AdapterResponse(
            httpStatus,
            mapOf("Content-Type" to "application/json"),
            Json.parseToJsonElement(bodyJson),
        )
    }

    /** 设置非 envelope 响应（body 直通） */
    fun rawResponse(httpStatus: Int, bodyJson: String) {
        response = AdapterResponse(httpStatus, emptyMap(), Json.parseToJsonElement(bodyJson))
    }
}
