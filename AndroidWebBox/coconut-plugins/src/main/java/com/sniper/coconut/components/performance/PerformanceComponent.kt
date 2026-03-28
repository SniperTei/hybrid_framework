package com.sniper.coconut.components.performance

import com.sniper.coconut.bridge.BridgePerformance
import com.sniper.coconut.component.BaseComponent
import com.sniper.coconut.component.ComponentMetadata
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Performance Component
 *
 * Exposes bridge call performance metrics collected by BridgePerformance.
 *
 * H5 Usage:
 *   Coconut.call('performance.getMetrics', {}, callback)
 *   Coconut.call('performance.getMethodStats', { method: 'network.request' }, callback)
 *   Coconut.call('performance.getSlowCalls', { threshold: 500 }, callback)
 *   Coconut.call('performance.reset', {}, callback)
 */
@ComponentMetadata(
    name = "performance",
    version = "1.0.0",
    description = "Bridge performance monitoring component"
)
class PerformanceComponent : BaseComponent() {

    override val name = "performance"
    override val version = "1.0.0"
    override val description = "Bridge performance monitoring component"

    override suspend fun handle(function: String, params: JsonObject?): JsonElement {
        return when (function) {
            "getMetrics" -> getMetrics()
            "getMethodStats" -> getMethodStats(params)
            "getSlowCalls" -> getSlowCalls(params)
            "reset" -> reset()
            else -> functionNotSupportedError(function)
        }
    }

    private fun getMetrics(): JsonElement {
        val uptime = System.currentTimeMillis() - BridgePerformance.startTime
        val calls = BridgePerformance.getTotalCalls()
        val success = BridgePerformance.getTotalSuccess()

        return buildJsonObject {
            put("uptimeMs", JsonPrimitive(uptime))
            put("totalCalls", JsonPrimitive(calls))
            put("totalSuccess", JsonPrimitive(success))
            put("totalFail", JsonPrimitive(calls - success))
            put("successRate", JsonPrimitive(if (calls > 0) "%.2f".format(success.toDouble() / calls) else "0.00"))
            put("methodCount", JsonPrimitive(BridgePerformance.getMethodStatsMap().size))
        }.let { success(it) }
    }

    private fun getMethodStats(params: JsonObject?): JsonElement {
        val method = getParam(params, "method")
        val all = getBoolParam(params, "all", false)
        val statsMap = BridgePerformance.getMethodStatsMap()

        if (all || method.isEmpty()) {
            val methods = statsMap.values.map { stats ->
                buildJsonObject {
                    put("method", JsonPrimitive(stats.method))
                    put("callCount", JsonPrimitive(stats.callCount))
                    put("successCount", JsonPrimitive(stats.successCount))
                    put("failCount", JsonPrimitive(stats.failCount))
                    put("avgDuration", JsonPrimitive(stats.avgDuration))
                    put("minDuration", JsonPrimitive(stats.minDuration))
                    put("maxDuration", JsonPrimitive(stats.maxDuration))
                    put("successRate", JsonPrimitive("%.2f".format(stats.successRate)))
                }
            }

            return buildJsonObject {
                put("methods", kotlinx.serialization.json.buildJsonArray { methods.forEach { add(it) } })
            }.let { success(it) }
        }

        val stats = statsMap[method] ?: return buildJsonObject {
            put("method", JsonPrimitive(method))
            put("callCount", JsonPrimitive(0))
        }.let { success(it) }

        return buildJsonObject {
            put("method", JsonPrimitive(stats.method))
            put("callCount", JsonPrimitive(stats.callCount))
            put("successCount", JsonPrimitive(stats.successCount))
            put("failCount", JsonPrimitive(stats.failCount))
            put("avgDuration", JsonPrimitive(stats.avgDuration))
            put("minDuration", JsonPrimitive(stats.minDuration))
            put("maxDuration", JsonPrimitive(stats.maxDuration))
            put("successRate", JsonPrimitive("%.2f".format(stats.successRate)))
        }.let { success(it) }
    }

    private fun getSlowCalls(params: JsonObject?): JsonElement {
        val threshold = getLongParam(params, "threshold", 500)

        val slowCalls = BridgePerformance.getCallHistory().values.flatten()
            .filter { it.durationMs > threshold }
            .sortedByDescending { it.durationMs }
            .take(50)

        val records = slowCalls.map { record ->
            buildJsonObject {
                put("method", JsonPrimitive(record.method))
                put("durationMs", JsonPrimitive(record.durationMs))
                put("success", JsonPrimitive(record.success))
                put("timestamp", JsonPrimitive(record.timestamp))
            }
        }

        return buildJsonObject {
            put("threshold", JsonPrimitive(threshold))
            put("slowCallCount", JsonPrimitive(slowCalls.size))
            put("slowCalls", kotlinx.serialization.json.buildJsonArray { records.forEach { add(it) } })
        }.let { success(it) }
    }

    private fun reset(): JsonElement {
        BridgePerformance.resetAll()
        return buildJsonObject {
            put("success", JsonPrimitive(true))
        }.let { success(it) }
    }

    private fun getLongParam(params: JsonObject?, key: String, default: Long): Long {
        return params?.get(key)?.let {
            (it as? JsonPrimitive)?.content?.toLongOrNull() ?: default
        } ?: default
    }
}
