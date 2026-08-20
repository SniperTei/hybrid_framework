package com.sniper.coconut.network

import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull

/** API 成功码（业务 envelope 约定，与桥接层 API_SUCCESS_CODE 一致） */
const val API_SUCCESS_CODE = "000000"

/**
 * HTTP 完整响应 = 业务 envelope + HTTP 传输层信息
 * 对齐服务端统一响应格式：
 * { code: "000000", statusCode: 200, msg: "...", data: {...}, timestamp: "..." }
 */
class HttpResponse {
    /** 业务码（字符串，如 "000000"） */
    var code: String = ""

    /** 服务端返回的状态码 */
    var statusCode: Int = 200

    /** 消息 */
    var msg: String = ""

    /** 业务数据 */
    var data: JsonElement? = null

    /** 服务端时间戳 */
    var timestamp: String = ""

    /** HTTP 状态码（传输层） */
    var httpStatus: Int = 200

    /** 响应头 */
    var headers: Map<String, String> = emptyMap()

    /** 请求耗时（毫秒） */
    var costTime: Long = 0

    /** 是否业务成功 */
    fun isSuccess(): Boolean = code == API_SUCCESS_CODE

    companion object {
        fun success(httpStatus: Int, data: JsonElement?, msg: String = "success"): HttpResponse {
            val resp = HttpResponse()
            resp.code = API_SUCCESS_CODE
            resp.httpStatus = httpStatus
            resp.statusCode = httpStatus
            resp.data = data
            resp.msg = msg
            return resp
        }

        fun error(code: String, httpStatus: Int, msg: String): HttpResponse {
            val resp = HttpResponse()
            resp.code = code
            resp.httpStatus = httpStatus
            resp.msg = msg
            return resp
        }
    }
}

/** JsonNull 视为无值（对齐 ArkTS 侧 `?? null` 语义） */
internal fun JsonElement?.orNullIfJsonNull(): JsonElement? = if (this is JsonNull) null else this
