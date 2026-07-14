package com.sniper.androidwebbox.components.network

import com.sniper.coconut.utils.Logger

/**
 * Factory that auto-selects HttpClient implementation at runtime.
 * Uses OkHttp if available in classpath, falls back to HttpURLConnection.
 */
object HttpClientFactory {

    private var client: HttpClient? = null

    fun create(): HttpClient {
        client?.let { return it }

        val instance = try {
            Class.forName("okhttp3.OkHttpClient")
            Logger.d(TAG, "OkHttp detected, using OkHttpHttpClient")
            OkHttpHttpClient()
        } catch (_: ClassNotFoundException) {
            Logger.d(TAG, "OkHttp not found, using UrlConnectionHttpClient")
            UrlConnectionHttpClient()
        }

        client = instance
        return instance
    }

    /** For testing: reset cached client */
    fun reset() {
        client = null
    }

    private const val TAG = "HttpClientFactory"
}
