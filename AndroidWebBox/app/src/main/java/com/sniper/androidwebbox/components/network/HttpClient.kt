package com.sniper.androidwebbox.components.network

/**
 * HTTP client abstraction for network requests.
 * Implementations: OkHttpHttpClient (preferred) or UrlConnectionHttpClient (fallback).
 */
interface HttpClient {
    suspend fun execute(request: HttpRequest): HttpResponse
}

data class HttpRequest(
    val url: String,
    val method: String,
    val headers: Map<String, String>,
    val body: String?,
    val contentType: String,
    val timeout: Int
)

data class HttpResponse(
    val statusCode: Int,
    val body: String,
    val headers: Map<String, String>
)
