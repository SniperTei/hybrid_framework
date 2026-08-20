package com.sniper.coconut.network.guard

/**
 * 出站 URL 守卫（SSRF 防护）
 *
 * 规则：
 * - scheme 必须是 http / https（coconut:// / file:// / resource:// / javascript: / 无 scheme 一律拒绝）
 * - allowedDomains 为空 = 放行所有 host
 * - allowedDomains 非空 = host 需精确命中某域名或为其子域名：
 *     host === d || host.endsWith("." + d)
 *   注意后缀匹配带 '.' 分隔，"api.foo.com.evil.com" 不会命中 "foo.com"
 */
data class UrlGuardResult(val allowed: Boolean = false, val reason: String = "")

object UrlGuard {
    private val ALLOWED_SCHEMES = listOf("http", "https")

    /**
     * 校验出站 URL
     * @param url 完整 URL（含 baseUrl 拼接后的）
     * @param allowedDomains 域名白名单（空 = 放行所有）
     */
    fun validate(url: String, allowedDomains: List<String>): UrlGuardResult {
        val schemeSep = url.indexOf("://")
        if (schemeSep < 0) {
            return UrlGuardResult(reason = "missing or invalid scheme (http/https only): '$url'")
        }

        val scheme = url.substring(0, schemeSep).lowercase()
        if (scheme !in ALLOWED_SCHEMES) {
            return UrlGuardResult(reason = "scheme '$scheme' is not allowed (http/https only)")
        }

        val host = extractHost(url, schemeSep + 3)
        if (host.isEmpty()) {
            return UrlGuardResult(reason = "empty host")
        }

        if (allowedDomains.isEmpty()) {
            return UrlGuardResult(allowed = true)
        }

        for (domain in allowedDomains) {
            val d = domain.trim().lowercase()
            if (d.isEmpty()) {
                continue
            }
            if (host == d || host.endsWith(".$d")) {
                return UrlGuardResult(allowed = true)
            }
        }

        return UrlGuardResult(reason = "host '$host' is not in allowedDomains")
    }

    /** 从 '://' 之后提取 host（到第一个 '/', '?', '#', ':' 为止） */
    private fun extractHost(url: String, hostStart: Int): String {
        var end = url.length
        for (ch in listOf('/', '?', '#', ':')) {
            val idx = url.indexOf(ch, hostStart)
            if (idx in 0 until end) {
                end = idx
            }
        }
        return url.substring(hostStart, end).lowercase()
    }
}
