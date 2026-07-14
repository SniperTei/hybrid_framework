package com.sniper.coconut.bridge

import com.sniper.coconut.bridge.SecurityAuditLog.AuditEntry
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * Unit tests for [SecurityAuditLog].
 *
 * Android-only — the iOS SDK does not include this audit-log singleton.
 */
class SecurityAuditLogTest {

    @Before
    fun setUp() {
        SecurityAuditLog.clear()
    }

    @After
    fun tearDown() {
        SecurityAuditLog.clear()
    }

    @Test
    fun record_addsEntry() {
        SecurityAuditLog.record(
            eventType = SecurityAuditLog.EVENT_SIGNATURE_INVALID,
            method = "device.getInfo",
            requestId = "r1",
            detail = "bad signature"
        )
        val entries = SecurityAuditLog.getEntries()
        assertEquals(1, entries.size)
        val entry = entries.first()
        assertEquals(SecurityAuditLog.EVENT_SIGNATURE_INVALID, entry.eventType)
        assertEquals("device.getInfo", entry.method)
        assertEquals("r1", entry.requestId)
        assertEquals("bad signature", entry.detail)
        assertTrue(entry.timestamp > 0)
    }

    @Test
    fun getEntries_returnsChronologicalList() {
        SecurityAuditLog.record("a", "m1", "r1", "d1")
        SecurityAuditLog.record("b", "m2", "r2", "d2")
        SecurityAuditLog.record("c", "m3", "r3", "d3")

        val entries: List<AuditEntry> = SecurityAuditLog.getEntries()
        assertEquals(listOf("r1", "r2", "r3"), entries.map { it.requestId })
        // Timestamps are non-decreasing (insertion order).
        for (i in 1 until entries.size) {
            assertTrue(entries[i].timestamp >= entries[i - 1].timestamp)
        }
    }

    @Test
    fun getSummary_returnsCountBySeverity() {
        SecurityAuditLog.record(SecurityAuditLog.EVENT_SIGNATURE_INVALID, "m", "r1", "d")
        SecurityAuditLog.record(SecurityAuditLog.EVENT_SIGNATURE_INVALID, "m", "r2", "d")
        SecurityAuditLog.record(SecurityAuditLog.EVENT_NONCE_REUSED, "m", "r3", "d")

        val summary = SecurityAuditLog.getSummary()
        assertEquals(2, summary[SecurityAuditLog.EVENT_SIGNATURE_INVALID])
        assertEquals(1, summary[SecurityAuditLog.EVENT_NONCE_REUSED])
    }

    @Test
    fun clear_removesAllEntries() {
        SecurityAuditLog.record("a", "m", "r1", "d")
        SecurityAuditLog.record("b", "m", "r2", "d")
        assertEquals(2, SecurityAuditLog.getEntries().size)

        SecurityAuditLog.clear()

        assertTrue(SecurityAuditLog.getEntries().isEmpty())
        assertTrue(SecurityAuditLog.getSummary().isEmpty())
    }

    @Test
    fun record_capsHistoryAtMaxSize() {
        // MAX_ENTRIES is 500 in production. Fill slightly past it and verify
        // the oldest entry is evicted (FIFO via removeAt(0)).
        repeat(510) { i ->
            SecurityAuditLog.record("type", "m", "r$i", "d")
        }
        val entries = SecurityAuditLog.getEntries()
        assertEquals(500, entries.size)
        // First 10 entries (r0..r9) should have been evicted; r10 is now the oldest.
        assertEquals("r10", entries.first().requestId)
        assertEquals("r509", entries.last().requestId)
    }
}
