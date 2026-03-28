package com.sniper.coconut.bridge

import com.sniper.coconut.utils.Logger
import java.util.concurrent.CopyOnWriteArrayList

/**
 * Security Audit Log
 *
 * Singleton in coconut-core to record security rejection events.
 * SecurityComponent in coconut-plugins reads from this.
 */
object SecurityAuditLog {

    private const val TAG = "SecurityAuditLog"
    private const val MAX_ENTRIES = 500

    data class AuditEntry(
        val eventType: String,
        val method: String,
        val requestId: String,
        val detail: String,
        val timestamp: Long = System.currentTimeMillis()
    )

    private val entries = CopyOnWriteArrayList<AuditEntry>()

    // Event types
    const val EVENT_DOMAIN_REJECTED = "domain_rejected"
    const val EVENT_RATE_LIMITED = "rate_limited"
    const val EVENT_PARAMS_OVERSIZED = "params_oversized"
    const val EVENT_SIGNATURE_INVALID = "signature_invalid"
    const val EVENT_SIGNATURE_EXPIRED = "signature_expired"
    const val EVENT_NONCE_REUSED = "nonce_reused"
    const val EVENT_TOKEN_INVALID = "token_invalid"

    /**
     * Record a security event
     */
    fun record(eventType: String, method: String, requestId: String, detail: String) {
        if (entries.size >= MAX_ENTRIES) {
            entries.removeAt(0)
        }
        val entry = AuditEntry(eventType, method, requestId, detail)
        entries.add(entry)
        Logger.d(TAG, "Audit: $eventType - $method - $detail")
    }

    /**
     * Get all audit entries
     */
    fun getEntries(): List<AuditEntry> = entries.toList()

    /**
     * Get entries filtered by event type
     */
    fun getEntriesByType(eventType: String): List<AuditEntry> =
        entries.filter { it.eventType == eventType }

    /**
     * Get entries with limit
     */
    fun getEntries(limit: Int): List<AuditEntry> =
        entries.takeLast(limit)

    /**
     * Get summary: count per event type
     */
    fun getSummary(): Map<String, Int> {
        val summary = mutableMapOf<String, Int>()
        for (entry in entries) {
            summary[entry.eventType] = (summary[entry.eventType] ?: 0) + 1
        }
        return summary
    }

    /**
     * Clear all entries
     */
    fun clear() {
        entries.clear()
        Logger.d(TAG, "Audit log cleared")
    }
}
