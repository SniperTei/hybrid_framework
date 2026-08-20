package com.sniper.androidwebbox.components.network

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import com.sniper.coconut.CoconutSDK
import com.sniper.coconut.component.BaseComponent
import com.sniper.coconut.component.ComponentContext
import com.sniper.coconut.component.ComponentMetadata
import com.sniper.coconut.network.HttpClient
import com.sniper.coconut.network.HttpConfig
import com.sniper.coconut.network.HttpErrorCode
import com.sniper.coconut.network.HttpMethod
import com.sniper.coconut.network.RequestOptions
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonPrimitive

/**
 * Topic emitted on network type/online changes (deduped).
 */
const val NETWORK_TOPIC_CHANGE = "network.change"

private val ALLOWED_METHODS = listOf("GET", "POST", "PUT", "DELETE")

/**
 * Network Component
 *
 * Bridges the standalone coconut-network engine to the H5 bridge:
 * - request: native HTTP via HttpClient (bypasses WebView CORS, unified
 *   outbound guard). Business-layer failure convention: bridge code 000000
 *   + success:false in the result payload.
 * - getNetworkType: current connectivity (wifi/cellular/ethernet/none/unknown).
 * - network.change: native → H5 push on connectivity change (deduped by
 *   type|online key), reusing the EventEmitter channel.
 *
 * The HttpClient is injectable for tests (FakeAdapter); by default it is
 * created once with allowedDomains re-synced from CoconutSDK config on
 * every request (Kotlin List is not aliasable, so sync per-request keeps
 * later CoconutSDK.configure() domain changes live).
 */
@ComponentMetadata(
    name = "network",
    version = "1.0.0",
    description = "Network request + connectivity component",
    dependencies = []
)
class NetworkComponent private constructor(
    private val client: HttpClient,
    private val usesSdkWhitelist: Boolean,
) : BaseComponent() {

    override val name = "network"
    override val version = "1.0.0"
    override val description = "Network request + connectivity component"
    override val methods = listOf("request", "getNetworkType")

    private var context: ComponentContext? = null
    private var netCallback: ConnectivityManager.NetworkCallback? = null
    private var lastStateKey: String = ""

    /** 默认构造：client 出站白名单与 CoconutSDK 入站白名单保持同步 */
    constructor() : this(HttpClient(HttpConfig()), true)

    /** 测试注入构造：client 自带配置，不触碰 CoconutSDK（JVM 单测环境不可加载） */
    constructor(client: HttpClient) : this(client, false)

    override suspend fun handle(function: String, params: JsonObject?): JsonElement {
        return when (function) {
            "request" -> requestHandler(params)
            "getNetworkType" -> getNetworkTypeHandler()
            else -> functionNotSupportedError(function)
        }
    }

    override suspend fun onInit(context: ComponentContext) {
        this.context = context
        registerNetworkCallback(context)
    }

    override suspend fun onCleanup() {
        unregisterNetworkCallback()
        lastStateKey = ""
    }

    /**
     * request: {url, method, headers, body, params, timeoutMs}
     * → {success, httpStatus, code, msg, data, headers, costTime, message}
     */
    private suspend fun requestHandler(params: JsonObject?): JsonElement {
        val url = getParam(params, "url")
        if (url.isEmpty()) {
            return error("200007", "url is required")
        }

        val methodStr = getParam(params, "method", "GET").uppercase()
        val method = when (methodStr) {
            "GET" -> HttpMethod.GET
            "POST" -> HttpMethod.POST
            "PUT" -> HttpMethod.PUT
            "DELETE" -> HttpMethod.DELETE
            // deliberate whitelist — PATCH/HEAD etc. deferred to a later round
            else -> return error(
                "200007",
                "method not allowed: $methodStr (allowed: ${ALLOWED_METHODS.joinToString("/")})",
            )
        }

        syncOutboundWhitelist()

        val options = RequestOptions(
            method = method,
            headers = params.stringMapOf("headers"),
            params = params.stringMapOf("params")?.takeIf { it.isNotEmpty() },
        )

        val timeoutMs = getIntParam(params, "timeoutMs", 0)

        val request = client.newRequest(url, options)
        params?.get("body")?.let {
            // raw JSON passthrough (contentType stays application/json)
            request.setBody(it)
        }
        if (timeoutMs > 0) {
            request.setTimeout(timeoutMs, timeoutMs)
        }

        val resp = request.buildCall().execute()

        // Outbound guard hit → surface as bridge security error (200007),
        // mirroring inbound BridgeSecurityValidator semantics.
        if (resp.code == HttpErrorCode.URL_BLOCKED.code.toString()) {
            return error("200007", resp.msg)
        }

        return success(buildJsonObject {
            put("success", JsonPrimitive(resp.isSuccess()))
            put("httpStatus", JsonPrimitive(resp.httpStatus))
            put("code", JsonPrimitive(resp.code))
            put("msg", JsonPrimitive(resp.msg))
            put("data", resp.data ?: JsonNull)
            put("headers", buildJsonObject {
                resp.headers.forEach { (k, v) -> put(k, JsonPrimitive(v)) }
            })
            put("costTime", JsonPrimitive(resp.costTime))
            put("message", JsonPrimitive(resp.msg))
        })
    }

    /**
     * getNetworkType → {type: wifi|cellular|ethernet|none|unknown, online, success}
     */
    private fun getNetworkTypeHandler(): JsonElement {
        val status = fetchNetworkType()
        return success(buildJsonObject {
            put("type", JsonPrimitive(status.type))
            put("online", JsonPrimitive(status.online))
            put("success", JsonPrimitive(true))
        })
    }

    /** Extract a string map from a nested params object */
    private fun JsonObject?.stringMapOf(key: String): Map<String, String>? {
        val obj = this?.get(key) as? JsonObject ?: return null
        val map = linkedMapOf<String, String>()
        for ((k, v) in obj) {
            if (v is JsonPrimitive) {
                map[k] = v.content
            }
        }
        return map
    }

    /** Re-sync outbound guard whitelist from CoconutSDK inbound config (per request, see class doc) */
    private fun syncOutboundWhitelist() {
        if (!usesSdkWhitelist || !CoconutSDK.isInitialized()) {
            return
        }
        client.getConfig().allowedDomains = CoconutSDK.getConfig().allowedDomains
    }

    private fun registerNetworkCallback(context: ComponentContext) {
        try {
            val cm = context.applicationContext
                .getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val callback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    pushCurrentState()
                }

                override fun onLost(network: Network) {
                    emitState("none", false)
                }

                override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) {
                    emitState(bearerToType(caps), true)
                }
            }
            cm.registerDefaultNetworkCallback(callback)
            netCallback = callback
        } catch (e: Exception) {
            com.sniper.coconut.utils.Logger.w(name, "registerNetworkCallback failed: ${e.message}")
        }
    }

    private fun unregisterNetworkCallback() {
        val callback = netCallback ?: return
        try {
            val ctx = context ?: return
            val cm = ctx.applicationContext
                .getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            cm.unregisterNetworkCallback(callback)
        } catch (e: Exception) {
            com.sniper.coconut.utils.Logger.w(name, "unregisterNetworkCallback failed: ${e.message}")
        } finally {
            netCallback = null
        }
    }

    private fun pushCurrentState() {
        val status = fetchNetworkType()
        emitState(status.type, status.online)
    }

    /** Emit network.change, deduped on type|online (first emit carries initial state) */
    internal fun emitState(type: String, online: Boolean) {
        val key = "$type|$online"
        if (key == lastStateKey) {
            return
        }
        lastStateKey = key
        val ctx = context ?: return
        ctx.eventEmitter.emit(
            NETWORK_TOPIC_CHANGE,
            buildJsonObject {
                put("type", JsonPrimitive(type))
                put("online", JsonPrimitive(online))
            },
        )
    }

    private class NetworkStatus(val type: String, val online: Boolean)

    private fun fetchNetworkType(): NetworkStatus {
        return try {
            val cm = context?.applicationContext
                ?.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                ?: return NetworkStatus("unknown", false)
            val network = cm.activeNetwork
                ?: return NetworkStatus("none", false)
            val caps = cm.getNetworkCapabilities(network)
                ?: return NetworkStatus("unknown", true)
            NetworkStatus(bearerToType(caps), true)
        } catch (e: Exception) {
            NetworkStatus("unknown", false)
        }
    }

    private fun bearerToType(caps: NetworkCapabilities): String {
        return when {
            caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
            else -> "unknown"
        }
    }
}
