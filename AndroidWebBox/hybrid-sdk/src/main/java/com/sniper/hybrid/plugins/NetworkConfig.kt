package com.sniper.hybrid.plugins

import okhttp3.Interceptor

/**
 * 网络请求配置类
 */
data class NetworkConfig(
    /** 基础URL */
    val baseUrl: String = "",

    /** 连接超时时间（毫秒） */
    val connectTimeout: Long = 30_000,

    /** 读取超时时间（毫秒） */
    val readTimeout: Long = 30_000,

    /** 写入超时时间（毫秒） */
    val writeTimeout: Long = 30_000,

    /** 默认请求头 */
    val defaultHeaders: Map<String, String> = emptyMap(),

    /** 是否启用缓存 */
    val enableCache: Boolean = false,

    /** 缓存大小（字节） */
    val cacheSize: Long = 10 * 1024 * 1024, // 10MB

    /** 缓存目录 */
    val cacheDir: String? = null,

    /** 重试次数 */
    val retryCount: Int = 0,

    /** 请求拦截器列表 */
    val requestInterceptors: List<Interceptor> = emptyList(),

    /** 响应拦截器列表 */
    val responseInterceptors: List<Interceptor> = emptyList()
) {
    class Builder {
        private var baseUrl: String = ""
        private var connectTimeout: Long = 30_000
        private var readTimeout: Long = 30_000
        private var writeTimeout: Long = 30_000
        private var defaultHeaders: Map<String, String> = emptyMap()
        private var enableCache: Boolean = false
        private var cacheSize: Long = 10 * 1024 * 1024
        private var cacheDir: String? = null
        private var retryCount: Int = 0
        private val requestInterceptors = mutableListOf<Interceptor>()
        private val responseInterceptors = mutableListOf<Interceptor>()

        fun setBaseUrl(url: String) = apply { baseUrl = url }
        fun setConnectTimeout(timeout: Long) = apply { connectTimeout = timeout }
        fun setReadTimeout(timeout: Long) = apply { readTimeout = timeout }
        fun setWriteTimeout(timeout: Long) = apply { writeTimeout = timeout }
        fun setDefaultHeaders(headers: Map<String, String>) = apply { defaultHeaders = headers }
        fun setEnableCache(enable: Boolean) = apply { enableCache = enable }
        fun setCacheSize(size: Long) = apply { cacheSize = size }
        fun setCacheDir(dir: String) = apply { cacheDir = dir }
        fun setRetryCount(count: Int) = apply { retryCount = count }

        fun addRequestInterceptor(interceptor: Interceptor) = apply {
            requestInterceptors.add(interceptor)
        }

        fun addResponseInterceptor(interceptor: Interceptor) = apply {
            responseInterceptors.add(interceptor)
        }

        fun build(): NetworkConfig {
            return NetworkConfig(
                baseUrl = baseUrl,
                connectTimeout = connectTimeout,
                readTimeout = readTimeout,
                writeTimeout = writeTimeout,
                defaultHeaders = defaultHeaders,
                enableCache = enableCache,
                cacheSize = cacheSize,
                cacheDir = cacheDir,
                retryCount = retryCount,
                requestInterceptors = requestInterceptors.toList(),
                responseInterceptors = responseInterceptors.toList()
            )
        }
    }

    companion object {
        /**
         * 创建默认配置
         */
        fun default() = Builder().build()
    }
}
