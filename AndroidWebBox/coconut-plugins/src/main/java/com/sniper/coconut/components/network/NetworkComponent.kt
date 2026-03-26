package com.sniper.coconut.components.network

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
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
 * Network Component
 *
 * Provides network status and connectivity information
 */
@ComponentMetadata(
    name = "network",
    version = "1.0.0",
    description = "Network status and connectivity component",
    dependencies = []
)
class NetworkComponent : BaseComponent() {

    override val name = "network"
    override val version = "1.0.0"
    override val description = "Network status and connectivity component"

    private var context: Context? = null
    private val connectivityManager: ConnectivityManager?
        get() = context?.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager

    override suspend fun handle(function: String, params: JsonObject?): JsonElement {
        return when (function) {
            "getType" -> getNetworkType()
            "getState" -> getNetworkState()
            "isConnected" -> isConnected()
            else -> functionNotSupportedError(function)
        }
    }

    protected override suspend fun onInit(context: ComponentContext) {
        this.context = context.applicationContext
        Logger.d(name, "Network component initialized with context")
    }

    /**
     * Get current network type
     */
    private suspend fun getNetworkType(): JsonElement {
        val type = when {
            isWifiConnected() -> "wifi"
            isCellularConnected() -> "cellular"
            isEthernetConnected() -> "ethernet"
            isVpnConnected() -> "vpn"
            else -> "unknown"
        }

        return buildJsonObject {
            put("type", JsonPrimitive(type))
        }.let { success(it) }
    }

    /**
     * Get detailed network state
     */
    private suspend fun getNetworkState(): JsonElement {
        val cm = connectivityManager
        val network = cm?.activeNetwork
        val capabilities = network?.let { cm.getNetworkCapabilities(it) }

        return buildJsonObject {
            put("isConnected", JsonPrimitive(capabilities != null))
            put("type", JsonPrimitive(getNetworkTypeString(capabilities)))
            put("isWifi", JsonPrimitive(capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true))
            put("isCellular", JsonPrimitive(capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true))
            put("isEthernet", JsonPrimitive(capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) == true))
            put("isVpn", JsonPrimitive(capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true))
            put("isRoaming", JsonPrimitive(capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_ROAMING) == false))
        }.let { success(it) }
    }

    /**
     * Check if connected
     */
    private suspend fun isConnected(): JsonElement {
        val isConnected = connectivityManager?.activeNetworkInfo?.isConnected == true
        return buildJsonObject {
            put("isConnected", JsonPrimitive(isConnected))
        }.let { success(it) }
    }

    private fun isWifiConnected(): Boolean {
        val capabilities = getNetworkCapabilities()
        return capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
    }

    private fun isCellularConnected(): Boolean {
        val capabilities = getNetworkCapabilities()
        return capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true
    }

    private fun isEthernetConnected(): Boolean {
        val capabilities = getNetworkCapabilities()
        return capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) == true
    }

    private fun isVpnConnected(): Boolean {
        val capabilities = getNetworkCapabilities()
        return capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true
    }

    private fun getNetworkCapabilities(): NetworkCapabilities? {
        val cm = connectivityManager ?: return null
        val network = cm.activeNetwork ?: return null
        return cm.getNetworkCapabilities(network)
    }

    private fun getNetworkTypeString(capabilities: NetworkCapabilities?): String {
        return when {
            capabilities == null -> "none"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN) -> "vpn"
            else -> "unknown"
        }
    }

    protected override suspend fun onCleanup() {
        context = null
        Logger.d(name, "Network component cleanup complete")
    }
}
