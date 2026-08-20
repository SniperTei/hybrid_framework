package com.sniper.coconut.network

/**
 * HTTP 全局配置
 * 启动时创建一次，传入 HttpClient
 * 不依赖任何 SDK
 */
class HttpConfig {
    /** 服务器基础地址 */
    var baseUrl: String = ""

    /** 公共请求头（所有请求都会带上，单次请求同名 header 覆盖） */
    var headers: MutableMap<String, String> = mutableMapOf()

    /** 连接超时（毫秒） */
    var connectTimeout: Int = 15000

    /** 读取超时（毫秒） */
    var readTimeout: Int = 30000

    /** 重试次数 */
    var retryCount: Int = 2

    /** 重试间隔（毫秒） */
    var retryDelay: Int = 1000

    /** 启用日志 */
    var enableLog: Boolean = false

    /** 日志中脱敏的 Header 字段 */
    var sensitiveHeaders: List<String> = listOf("Authorization", "Cookie")

    /** 日志中脱敏的参数字段 */
    var sensitiveParams: List<String> = listOf("password", "token", "secret")

    /**
     * 出站域名白名单（SSRF 守卫）
     * 空 = 放行所有 host；非空 = host 需精确命中或为其子域名（host == d || host.endsWith("." + d)）
     */
    var allowedDomains: List<String> = emptyList()
}
