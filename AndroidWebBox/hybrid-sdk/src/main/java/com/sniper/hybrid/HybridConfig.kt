package com.sniper.hybrid

import android.content.Context

/**
 * Hybrid框架配置类
 */
data class HybridConfig(
    /** 默认加载的URL */
    val defaultUrl: String = "file:///android_asset/index.html",

    /** 调试模式，开启后可看到日志 */
    val debugMode: Boolean = false,

    /** 域名白名单，空则允许所有域名 */
    val allowedDomains: List<String> = emptyList(),

    /** WebView UserAgent */
    val userAgent: String? = null,

    /** 是否启用缓存 */
    val enableCache: Boolean = true,

    /** 是否启用本地存储 */
    val enableDomStorage: Boolean = true,

    /** 是否启用数据库 */
    val enableDatabase: Boolean = true,

    /** 缓存模式，默认LOAD_DEFAULT */
    val cacheMode: Int = android.webkit.WebSettings.LOAD_DEFAULT,

    /** 是否允许文件访问 */
    val allowFileAccess: Boolean = true,

    /** 是否允许内容访问 */
    val allowContentAccess: Boolean = true,

    /** 是否启用混合内容模式（允许HTTPS页面加载HTTP资源） */
    val mixedContentMode: Int = android.webkit.WebSettings.MIXED_CONTENT_NEVER_ALLOW,

    /** 文件下载目录，null则使用系统默认 */
    val downloadDir: String? = null,

    /** 自定义错误页面 */
    val errorPageUrl: String? = null,

    /** WebView预加载 */
    val preloadWebView: Boolean = true
) {
    class Builder {
        private var defaultUrl: String = "file:///android_asset/index.html"
        private var debugMode: Boolean = false
        private var allowedDomains: List<String> = emptyList()
        private var userAgent: String? = null
        private var enableCache: Boolean = true
        private var enableDomStorage: Boolean = true
        private var enableDatabase: Boolean = true
        private var cacheMode: Int = android.webkit.WebSettings.LOAD_DEFAULT
        private var allowFileAccess: Boolean = true
        private var allowContentAccess: Boolean = true
        private var mixedContentMode: Int = android.webkit.WebSettings.MIXED_CONTENT_NEVER_ALLOW
        private var downloadDir: String? = null
        private var errorPageUrl: String? = null
        private var preloadWebView: Boolean = true

        fun setDefaultUrl(url: String) = apply { defaultUrl = url }
        fun setDebugMode(debug: Boolean) = apply { debugMode = debug }
        fun setAllowedDomains(domains: List<String>) = apply { allowedDomains = domains }
        fun setUserAgent(agent: String) = apply { userAgent = agent }
        fun setEnableCache(enable: Boolean) = apply { enableCache = enable }
        fun setEnableDomStorage(enable: Boolean) = apply { enableDomStorage = enable }
        fun setEnableDatabase(enable: Boolean) = apply { enableDatabase = enable }
        fun setCacheMode(mode: Int) = apply { cacheMode = mode }
        fun setAllowFileAccess(allow: Boolean) = apply { allowFileAccess = allow }
        fun setAllowContentAccess(allow: Boolean) = apply { allowContentAccess = allow }
        fun setMixedContentMode(mode: Int) = apply { mixedContentMode = mode }
        fun setDownloadDir(dir: String) = apply { downloadDir = dir }
        fun setErrorPageUrl(url: String) = apply { errorPageUrl = url }
        fun setPreloadWebView(preload: Boolean) = apply { preloadWebView = preload }

        fun build(): HybridConfig {
            return HybridConfig(
                defaultUrl = defaultUrl,
                debugMode = debugMode,
                allowedDomains = allowedDomains,
                userAgent = userAgent,
                enableCache = enableCache,
                enableDomStorage = enableDomStorage,
                enableDatabase = enableDatabase,
                cacheMode = cacheMode,
                allowFileAccess = allowFileAccess,
                allowContentAccess = allowContentAccess,
                mixedContentMode = mixedContentMode,
                downloadDir = downloadDir,
                errorPageUrl = errorPageUrl,
                preloadWebView = preloadWebView
            )
        }
    }

    /**
     * 检查URL是否在白名单中
     */
    fun isUrlAllowed(url: String?): Boolean {
        if (allowedDomains.isEmpty()) return true
        if (url.isNullOrEmpty()) return false

        return allowedDomains.any { domain ->
            url.contains(domain) || url.startsWith("file://")
        }
    }

    companion object {
        /**
         * 创建默认配置
         */
        fun default() = Builder().build()

        /**
         * 从Application创建配置
         */
        fun fromContext(context: Context): HybridConfig {
            return default()
        }
    }
}
