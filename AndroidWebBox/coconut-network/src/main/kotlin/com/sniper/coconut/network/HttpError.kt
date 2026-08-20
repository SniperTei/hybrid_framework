package com.sniper.coconut.network

/**
 * HTTP 错误码常量
 * 负数区间，避免和 HTTP 状态码、业务码冲突
 */
enum class HttpErrorCode(val code: Int) {
    /** 网络错误（DNS、连接失败等） */
    NETWORK_ERROR(-1001),

    /** 超时 */
    TIMEOUT_ERROR(-1002),

    /** SSL 证书错误 */
    SSL_ERROR(-1003),

    /** 出站 URL 被守卫拦截（scheme 非法或 host 不在白名单） */
    URL_BLOCKED(-1004),

    /** Token 过期 */
    TOKEN_EXPIRED(-2001),

    /** Token 无效 */
    TOKEN_INVALID(-2002),

    /** 服务器错误 */
    SERVER_ERROR(-3001),
}

/**
 * HTTP 错误分类
 */
object HttpError {
    /** 判断是否为网络层错误 */
    fun isNetworkError(code: Int): Boolean = code in -1099..-1001

    /** 判断是否为 Token 相关错误 */
    fun isTokenError(code: Int): Boolean =
        code == HttpErrorCode.TOKEN_EXPIRED.code || code == HttpErrorCode.TOKEN_INVALID.code

    /** 判断是否可重试 */
    fun isRetryable(code: Int): Boolean =
        code == HttpErrorCode.NETWORK_ERROR.code || code == HttpErrorCode.TIMEOUT_ERROR.code
}
