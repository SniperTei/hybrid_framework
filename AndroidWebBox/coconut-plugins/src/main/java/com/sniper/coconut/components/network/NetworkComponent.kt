package com.sniper.coconut.components.network

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import com.sniper.coconut.component.BaseComponent
import com.sniper.coconut.component.ComponentContext
import com.sniper.coconut.component.ComponentMetadata
import com.sniper.coconut.utils.Logger
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import java.io.BufferedReader
import java.io.DataOutputStream
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

/**
 * Network Component (Enhanced)
 *
 * Provides:
 * - Network status checking
 * - Native HTTP request proxy for H5 (bypasses CORS)
 * - Cookie sync support
 * - Auto-injected headers (token, version, device info)
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

    override suspend fun onInit(ctx: ComponentContext) {
        componentContext = ctx
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
     * params: { url, method, headers, body, timeout, contentType }
     */
    private suspend fun httpRequest(params: JsonObject?): JsonElement = withContext(Dispatchers.IO) {
        val url = getParam(params, "url")
        if (url.isEmpty()) return@withContext error("900001", "url is required")

        val method = getParam(params, "method", "GET").uppercase()
        val timeout = getIntParam(params, "timeout", 15000)
        val contentType = getParam(params, "contentType", "application/json")
        val body = getParam(params, "body", "")

        try {
            Logger.d(name, "Native request: $method $url")

            val connection = URL(url).openConnection() as HttpURLConnection
            connection.requestMethod = method
            connection.connectTimeout = timeout
            connection.readTimeout = timeout
            connection.instanceFollowRedirects = true

            // Auto-inject extra headers
            extraHeaders.forEach { (k, v) -> connection.setRequestProperty(k, v) }

            // H5-provided headers
            params?.get("headers")?.let { headersElem ->
                if (headersElem is JsonObject) {
                    headersElem.forEach { (k, v) ->
                        if (v is JsonPrimitive && v.isString) {
                            connection.setRequestProperty(k, v.content)
                        }
                    }
                }
            }

            // Write body for non-GET
            if (method != "GET" && body.isNotEmpty()) {
                connection.doOutput = true
                connection.setRequestProperty("Content-Type", contentType)
                DataOutputStream(connection.outputStream).use { dos ->
                    dos.writeBytes(body)
                    dos.flush()
                }
            }

            val responseCode = connection.responseCode
            val responseBody = if (responseCode in 200..299) {
                BufferedReader(InputStreamReader(connection.inputStream)).readText()
            } else {
                try {
                    BufferedReader(InputStreamReader(connection.errorStream)).readText()
                } catch (e: Exception) {
                    ""
                }
            }

            Logger.d(name, "Native response: $responseCode (${responseBody.length} bytes)")

            buildJsonObject {
                put("statusCode", JsonPrimitive(responseCode))
                put("body", JsonPrimitive(responseBody))
                put("headers", JsonPrimitive(connection.headerFields.toString()))
            }.let { success(it) }
        } catch (e: Exception) {
            Logger.e(name, "Request failed: $url", e)
            buildJsonObject {
                put("statusCode", JsonPrimitive(-1))
                put("error", JsonPrimitive(e.message ?: "Request failed"))
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
    }
}
