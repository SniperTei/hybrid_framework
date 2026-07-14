package com.sniper.coconut.bridge

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import kotlin.concurrent.thread

/**
 * Unit tests for [BridgePerformance] metrics collection.
 *
 * Android-only — there is no direct iOS counterpart; the iOS performance
 * collector lives in the app module, not the SDK.
 */
class BridgePerformanceTest {

    @Before
    fun setUp() {
        BridgePerformance.resetAll()
    }

    @After
    fun tearDown() {
        BridgePerformance.resetAll()
    }

    @Test
    fun record_incrementsTotalCalls() {
        assertEquals(0L, BridgePerformance.getTotalCalls())
        BridgePerformance.record("device.getInfo", durationMs = 10, success = true)
        BridgePerformance.record("device.getInfo", durationMs = 5, success = false)
        assertEquals(2L, BridgePerformance.getTotalCalls())
    }

    @Test
    fun getMethodStatsMap_returnsPerMethodStats() {
        BridgePerformance.record("device.getInfo", durationMs = 10, success = true)
        BridgePerformance.record("network.get", durationMs = 20, success = true)

        val stats = BridgePerformance.getMethodStatsMap()
        assertTrue(stats.containsKey("device.getInfo"))
        assertTrue(stats.containsKey("network.get"))
        assertEquals(1L, stats["device.getInfo"]?.callCount)
        assertEquals(1L, stats["network.get"]?.callCount)
    }

    @Test
    fun record_tracksSuccessAndFailure() {
        BridgePerformance.record("m", 10, true)
        BridgePerformance.record("m", 5, false)
        BridgePerformance.record("m", 7, true)

        val stats = BridgePerformance.getMethodStatsMap()["m"]
        assertEquals(3L, stats?.callCount)
        assertEquals(2L, stats?.successCount)
        assertEquals(1L, stats?.failCount)
        assertEquals(2L, BridgePerformance.getTotalSuccess())
        // min/max across all 3
        assertEquals(5L, stats?.minDuration)
        assertEquals(10L, stats?.maxDuration)
    }

    @Test
    fun resetAll_clearsAllStats() {
        BridgePerformance.record("device.getInfo", 10, true)
        BridgePerformance.resetAll()

        assertEquals(0L, BridgePerformance.getTotalCalls())
        assertEquals(0L, BridgePerformance.getTotalSuccess())
        assertTrue(BridgePerformance.getMethodStatsMap().isEmpty())
        assertTrue(BridgePerformance.getCallHistory().isEmpty())
    }

    @Test
    fun concurrentRecords_areThreadSafe() {
        val threadCount = 8
        val perThread = 200
        val threads = (0 until threadCount).map {
            thread {
                repeat(perThread) { i ->
                    BridgePerformance.record("m", i.toLong(), success = (i % 2 == 0))
                }
            }
        }
        threads.forEach { it.join() }

        val totalExpected = (threadCount * perThread).toLong()
        assertEquals(totalExpected, BridgePerformance.getTotalCalls())
        assertEquals(totalExpected, BridgePerformance.getMethodStatsMap()["m"]?.callCount)
    }
}
