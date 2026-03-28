package com.sniper.coconut.bridge

import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

/**
 * Bridge Performance Collector
 *
 * Lightweight singleton in coconut-core to record bridge call metrics.
 * PerformanceComponent in coconut-plugins reads from this.
 */
object BridgePerformance {

    data class CallRecord(
        val method: String,
        val durationMs: Long,
        val success: Boolean,
        val timestamp: Long = System.currentTimeMillis()
    )

    data class MethodStats(
        val method: String,
        var callCount: Long = 0,
        var successCount: Long = 0,
        var failCount: Long = 0,
        var totalDuration: Long = 0,
        var minDuration: Long = Long.MAX_VALUE,
        var maxDuration: Long = 0
    ) {
        val avgDuration: Long get() = if (callCount > 0) totalDuration / callCount else 0
        val successRate: Double get() = if (callCount > 0) successCount.toDouble() / callCount else 0.0
    }

    private val callHistory = ConcurrentHashMap<String, MutableList<CallRecord>>()
    private val methodStatsMap = ConcurrentHashMap<String, MethodStats>()
    private val totalCalls = AtomicLong(0)
    private val totalSuccess = AtomicLong(0)
    @Volatile
    var startTime: Long = System.currentTimeMillis()
        private set

    private const val MAX_HISTORY_PER_METHOD = 100

    fun record(method: String, durationMs: Long, success: Boolean) {
        totalCalls.incrementAndGet()
        if (success) totalSuccess.incrementAndGet()

        methodStatsMap.compute(method) { _, existing ->
            val stats = existing ?: MethodStats(method)
            stats.callCount++
            if (success) stats.successCount++ else stats.failCount++
            stats.totalDuration += durationMs
            stats.minDuration = minOf(stats.minDuration, durationMs)
            stats.maxDuration = maxOf(stats.maxDuration, durationMs)
            stats
        }

        callHistory.compute(method) { _, list ->
            val l = list ?: mutableListOf()
            l.add(CallRecord(method, durationMs, success))
            if (l.size > MAX_HISTORY_PER_METHOD) l.removeAt(0)
            l
        }
    }

    fun getTotalCalls(): Long = totalCalls.get()
    fun getTotalSuccess(): Long = totalSuccess.get()
    fun getMethodStatsMap(): Map<String, MethodStats> = methodStatsMap.toMap()
    fun getCallHistory(): Map<String, List<CallRecord>> = callHistory.mapValues { it.value.toList() }

    fun resetAll() {
        callHistory.clear()
        methodStatsMap.clear()
        totalCalls.set(0)
        totalSuccess.set(0)
        startTime = System.currentTimeMillis()
    }
}
