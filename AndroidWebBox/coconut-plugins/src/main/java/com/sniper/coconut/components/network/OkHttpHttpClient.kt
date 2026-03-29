package com.sniper.coconut.components.network

import com.sniper.coconut.utils.Logger
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request.Builder
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

/**
 * HttpClient implementation using OkHttp (preferred when available).
 * Benefits: connection pooling, retry, interceptors, better timeout handling.
 */
class OkHttpHttpClient : HttpClient {

    private val client: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(15, TimeUnit.SECONDS)
            .writeTimeout(15, TimeUnit.SECONDS)
            .followRedirects(true)
            .build()
    }

    override suspend fun execute(request: HttpRequest): HttpResponse = withContext(Dispatchers.IO) {
        try {
            val requestBuilder = Builder().url(request.url)

            // Apply headers
            request.headers.forEach { (k, v) -> requestBuilder.addHeader(k, v) }

            // Build body for non-GET methods
            if (request.method != "GET" && !request.body.isNullOrEmpty()) {
                val mediaType = request.contentType.toMediaType()
                val body = request.body.toRequestBody(mediaType)
                requestBuilder.method(request.method, body)
            } else {
                requestBuilder.method(request.method, null)
            }

            // Override client timeouts with request-specific values
            val tailoredClient = client.newBuilder()
                .connectTimeout(request.timeout.toLong(), TimeUnit.MILLISECONDS)
                .readTimeout(request.timeout.toLong(), TimeUnit.MILLISECONDS)
                .writeTimeout(request.timeout.toLong(), TimeUnit.MILLISECONDS)
                .build()

            val response = tailoredClient.newCall(requestBuilder.build()).execute()

            val responseBody = response.body?.string() ?: ""
            val responseHeaders = response.headers.toMap()

            Logger.d(TAG, "Response: ${response.code} (${responseBody.length} bytes)")

            HttpResponse(response.code, responseBody, responseHeaders)
        } catch (e: Exception) {
            Logger.e(TAG, "Request failed: ${request.url}", e)
            HttpResponse(-1, e.message ?: "Request failed", emptyMap())
        }
    }

    companion object {
        private const val TAG = "OkHttpHttpClient"
    }
}
