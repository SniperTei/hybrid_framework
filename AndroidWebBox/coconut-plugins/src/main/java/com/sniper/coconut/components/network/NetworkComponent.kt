package com.sniper.coconut.components.network

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import com.sniper.coconut.component.BaseComponent
import com.sniper.coconut.component.ComponentContext
import com.sniper.coconut.component.ComponentMetadata
import com.sniper.coconut.utils.Logger
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Network Component (Enhanced)
 *
 * Provides:
 * - Network status checking
 * - Native HTTP request proxy for H5 (bypasses CORS)
 * - Cookie sync support
 * - Auto-injected headers (token, version, device info)
 *
 * HTTP implementation is auto-selected at runtime:
 * - OkHttp (preferred) when available in host app classpath
 * - HttpURLConnection (fallback) when OkHttp is not present
 *
 * H5 Usage:
 *   Coconut.call('network.request', {
 *     url: 'https://api.example.com/data',
 *     method: 'GET',
 *     headers: { 'X-Custom': 'value' },
 *     body: null,
 *     timeout: 15000
 *   }, callback)
 */
@ComponentMetadata(
    name = "network",
    version = "2.0.0",
    description = "Network status and native HTTP proxy component"
)
class NetworkComponent : BaseComponent() {

    override val name = "network"
    override val version = "2.0.0"
    override val description = "Network status and native HTTP proxy component"

    private var componentContext: ComponentContext? = null
    private val connectivityManager: ConnectivityManager?
        get() = componentContext?.applicationContext?.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager

    // Extra headers to auto-inject (e.g. token, version)
    private val extraHeaders = mutableMapOf<String, String>()

    private var httpClient: HttpClient? = null

    override suspend fun onInit(ctx: ComponentContext) {
        componentContext = ctx
        httpClient = HttpClientFactory.create()
        Logger.d(name, "Using ${httpClient?.javaClass?.simpleName}")
    }

    override suspend fun handle(function: String, params: JsonObject?): JsonElement {
        return when (function) {
            "getType" -> getNetworkType()
            "getState" -> getNetworkState()
            "isConnected" -> isConnected()
            "request" -> httpRequest(params)
            "get" -> httpGet(params)
            "post" -> httpPost(params)
            else -> functionNotSupportedError(function)
        }
    }

    // ---- Network Status ----

    private fun getNetworkType(): JsonElement {
        val capabilities = getNetworkCapabilities()
        val type = when {
            capabilities == null -> "none"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN) -> "vpn"
            else -> "unknown"
        }
        return buildJsonObject { put("type", JsonPrimitive(type)) }.let { success(it) }
    }

    private fun getNetworkState(): JsonElement {
        val capabilities = getNetworkCapabilities()
        return buildJsonObject {
            put("isConnected", JsonPrimitive(capabilities != null))
            put("type", JsonPrimitive(
                when {
                    capabilities == null -> "none"
                    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
                    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
                    else -> "unknown"
                }
            ))
        }.let { success(it) }
    }

    private fun isConnected(): JsonElement {
        val connected = getNetworkCapabilities() != null
        return buildJsonObject { put("isConnected", JsonPrimitive(connected)) }.let { success(it) }
    }

    private fun getNetworkCapabilities(): NetworkCapabilities? {
        val cm = connectivityManager ?: return null
        val network = cm.activeNetwork ?: return null
        return cm.getNetworkCapabilities(network)
    }

    // ---- Native HTTP Proxy ----

    /**
     * Generic HTTP request (H5 calls this to bypass CORS)
     * Delegates to HttpClient implementation (OkHttp or HttpURLConnection)
     */
    private suspend fun httpRequest(params: JsonObject?): JsonElement {
        val url = getParam(params, "url")
        if (url.isEmpty()) return error("900001", "url is required")

        val client = httpClient ?: HttpClientFactory.create()

        val method = getParam(params, "method", "GET").uppercase()
        val timeout = getIntParam(params, "timeout", 15000)
        val contentType = getParam(params, "contentType", "application/json")
        val body = getParam(params, "body", "")

        // Merge extra headers + H5-provided headers
        val headers = mutableMapOf<String, String>()
        headers.putAll(extraHeaders)
        params?.get("headers")?.let { headersElem ->
            if (headersElem is JsonObject) {
                headersElem.forEach { (k, v) ->
                    if (v is JsonPrimitive && v.isString) {
                        headers[k] = v.content
                    }
                }
            }
        }

        Logger.d(name, "Native request: $method $url")

        val request = HttpRequest(
            url = url,
            method = method,
            headers = headers,
            body = body.ifEmpty { null },
            contentType = contentType,
            timeout = timeout
        )

        val response = client.execute(request)

        return if (response.statusCode == -1) {
            buildJsonObject {
                put("statusCode", JsonPrimitive(-1))
                put("error", JsonPrimitive(response.body))
            }.let { success(it) }
        } else {
            buildJsonObject {
                put("statusCode", JsonPrimitive(response.statusCode))
                put("body", JsonPrimitive(response.body))
                put("headers", JsonPrimitive(response.headers.toString()))
            }.let { success(it) }
        }
    }

    /**
     * Shorthand GET
     */
    private suspend fun httpGet(params: JsonObject?): JsonElement {
        val mergedParams = buildJsonObject {
            params?.forEach { (k, v) -> put(k, v) }
            put("method", JsonPrimitive("GET"))
        }
        return httpRequest(mergedParams)
    }

    /**
     * Shorthand POST
     */
    private suspend fun httpPost(params: JsonObject?): JsonElement {
        val mergedParams = buildJsonObject {
            params?.forEach { (k, v) -> put(k, v) }
            put("method", JsonPrimitive("POST"))
        }
        return httpRequest(mergedParams)
    }

    /**
     * Add extra header to auto-inject
     */
    fun addExtraHeader(key: String, value: String) {
        extraHeaders[key] = value
    }

    override suspend fun onCleanup() {
        componentContext = null
        extraHeaders.clear()
        httpClient = null
    }
}
