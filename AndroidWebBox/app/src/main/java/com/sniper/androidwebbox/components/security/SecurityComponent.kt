package com.sniper.androidwebbox.components.security

import com.sniper.coconut.bridge.BridgeTokenManager
import com.sniper.coconut.bridge.RequestSignatureValidator
import com.sniper.coconut.bridge.SecurityAuditLog
import com.sniper.coconut.component.BaseComponent
import com.sniper.coconut.component.ComponentContext
import com.sniper.coconut.component.ComponentMetadata
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Security Component
 *
 * Exposes security audit log and configuration to H5.
 *
 * H5 Usage:
 *   Coconut.call('security.getAuditLog', {}, callback)
 *   Coconut.call('security.getAuditLog', { type: 'token_invalid', limit: 50 }, callback)
 *   Coconut.call('security.getAuditSummary', {}, callback)
 *   Coconut.call('security.getSecurityConfig', {}, callback)
 *   Coconut.call('security.clearAuditLog', {}, callback)
 */
@ComponentMetadata(
    name = "security",
    version = "1.0.0",
    description = "Security audit and configuration component"
)
class SecurityComponent : BaseComponent() {

    override val name = "security"
    override val version = "1.0.0"
    override val description = "Security audit and configuration component"

    private var componentContext: ComponentContext? = null

    override suspend fun onInit(ctx: ComponentContext) {
        componentContext = ctx
    }

    override suspend fun handle(function: String, params: JsonObject?): JsonElement {
        return when (function) {
            "getAuditLog" -> getAuditLog(params)
            "getAuditSummary" -> getAuditSummary()
            "getSecurityConfig" -> getSecurityConfig()
            "clearAuditLog" -> clearAuditLog()
            else -> functionNotSupportedError(function)
        }
    }

    private fun getAuditLog(params: JsonObject?): JsonElement {
        val type = getParam(params, "type")
        val limit = getIntParam(params, "limit", 100)

        val entries = if (type.isNotEmpty()) {
            SecurityAuditLog.getEntriesByType(type)
        } else {
            SecurityAuditLog.getEntries(limit)
        }

        val records = entries.map { entry ->
            buildJsonObject {
                put("eventType", JsonPrimitive(entry.eventType))
                put("method", JsonPrimitive(entry.method))
                put("requestId", JsonPrimitive(entry.requestId))
                put("detail", JsonPrimitive(entry.detail))
                put("timestamp", JsonPrimitive(entry.timestamp))
            }
        }

        return buildJsonObject {
            put("count", JsonPrimitive(records.size))
            put("entries", kotlinx.serialization.json.buildJsonArray { records.forEach { add(it) } })
        }.let { success(it) }
    }

    private fun getAuditSummary(): JsonElement {
        val summary = SecurityAuditLog.getSummary()
        val summaryJson = summary.map { (type, count) ->
            buildJsonObject {
                put("eventType", JsonPrimitive(type))
                put("count", JsonPrimitive(count))
            }
        }

        return buildJsonObject {
            put("totalEvents", JsonPrimitive(summary.values.sum()))
            put("summary", kotlinx.serialization.json.buildJsonArray { summaryJson.forEach { add(it) } })
        }.let { success(it) }
    }

    private fun getSecurityConfig(): JsonElement {
        return buildJsonObject {
            put("bridgeTokenEnabled", JsonPrimitive(BridgeTokenManager.enabled))
            put("requestSigningEnabled", JsonPrimitive(RequestSignatureValidator.enabled))
            put("signingTimestampToleranceMs", JsonPrimitive(RequestSignatureValidator.timestampToleranceMs))
        }.let { success(it) }
    }

    private fun clearAuditLog(): JsonElement {
        SecurityAuditLog.clear()
        return buildJsonObject {
            put("success", JsonPrimitive(true))
        }.let { success(it) }
    }

    override suspend fun onCleanup() {
        componentContext = null
    }
}
