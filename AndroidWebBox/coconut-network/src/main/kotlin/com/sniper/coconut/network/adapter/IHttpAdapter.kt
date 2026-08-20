package com.sniper.coconut.network.adapter

import kotlinx.serialization.json.JsonElement

/**
 * 传输层接口 — 不依赖任何网络 SDK
 * 换底层（系统栈 / 第三方如 OkHttp / 测试 Fake）只需新增一个 Adapter 实现
 *
 * Adapter 契约：AdapterResponse.body 必须是已解析的 JsonElement
 * （JSON 响应解析成对象/基元；非 JSON 响应包装为 JsonPrimitive 字符串）
 */

/** 文件上传表单项 */
data class FormDataItem(
    val name: String,
    val contentType: String,
    val remoteFileName: String? = null,
    val data: ByteArray,
)

/** Adapter 层的请求对象 */
data class AdapterRequest(
    val method: String,
    val url: String,
    val headers: Map<String, String>,
    val body: JsonElement?,
    val contentType: String,
    val connectTimeout: Int,
    val readTimeout: Int,
    val multiFormDataList: List<FormDataItem>,
)

/** Adapter 层的响应对象 */
data class AdapterResponse(
    val httpStatus: Int,
    val headers: Map<String, String>,
    val body: JsonElement?,
)

/** 传输层接口 */
interface IHttpAdapter {
    suspend fun sendRequest(request: AdapterRequest): AdapterResponse
}
