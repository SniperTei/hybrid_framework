package com.sniper.coconut.event

import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Unit tests for [EventEmitter].
 *
 * Uses a capturing jsExecutor to assert the exact JS payload that would be
 * dispatched to the WebView. Real WebView integration is exercised by
 * instrumented tests (out of scope for the JVM suite).
 */
class EventEmitterTest {

    private fun capturingEmitter(): Pair<EventEmitter, MutableList<String>> {
        val scripts = mutableListOf<String>()
        val emitter = EventEmitter().apply {
            jsExecutor = { scripts += it }
        }
        return emitter to scripts
    }

    @Test
    fun subscribe_then_emit_deliversToSubscriber() {
        val (emitter, scripts) = capturingEmitter()

        emitter.subscribe("test.echo", "sub_1")
        emitter.emit("test.echo", buildJsonObject { put("hello", "world") })

        assertEquals(1, scripts.size)
        assertEquals(1, emitter.size())
        // Script shape: window.__coconutEvent('...json...')
        assertTrue("script should call __coconutEvent", scripts[0].startsWith("window.__coconutEvent('"))
        assertTrue("script should contain topic", scripts[0].contains("\"topic\":\"test.echo\""))
        assertTrue("script should contain subscriptionId", scripts[0].contains("\"subscriptionId\":\"sub_1\""))
        assertTrue("script should contain data", scripts[0].contains("\"hello\":\"world\""))
    }

    @Test
    fun unsubscribe_blocksSubsequentEmit() {
        val (emitter, scripts) = capturingEmitter()

        emitter.subscribe("test.echo", "sub_1")
        emitter.unsubscribe("sub_1")
        emitter.emit("test.echo")

        assertTrue("no script should be dispatched after unsubscribe", scripts.isEmpty())
        assertEquals(0, emitter.size())
    }

    @Test
    fun multiple_subscribers_for_same_topic_allReceive() {
        val (emitter, scripts) = capturingEmitter()

        emitter.subscribe("network.change", "sub_a")
        emitter.subscribe("network.change", "sub_b")
        emitter.emit("network.change", JsonPrimitive(42))

        assertEquals(2, scripts.size)
        // ConcurrentHashMap iteration order is undefined — assert by content set
        val ids = scripts.mapNotNull { extractSubscriptionId(it) }.toSet()
        assertTrue("both subscribers should receive", ids == setOf("sub_a", "sub_b"))
        scripts.forEach { assertTrue("payload should be included", it.contains("\"data\":42")) }
    }

    @Test
    fun emit_withNoMatchingTopic_isDropped() {
        val (emitter, scripts) = capturingEmitter()

        emitter.subscribe("network.change", "sub_a")
        emitter.emit("app.foreground")  // different topic

        assertTrue(scripts.isEmpty())
    }

    @Test
    fun echo_roundTrip_deliversTestEchoWithPayload() {
        val (emitter, scripts) = capturingEmitter()

        emitter.subscribe("test.echo", "sub_echo")
        emitter.emit("test.echo", buildJsonObject { put("hello", "world") })

        assertEquals(1, scripts.size)
        assertTrue(scripts[0].contains("\"topic\":\"test.echo\""))
        assertTrue(scripts[0].contains("\"hello\":\"world\""))
    }

    // ---- Edge cases ----

    @Test
    fun emit_without_jsExecutor_isSilentlyDropped() {
        val emitter = EventEmitter()  // no jsExecutor
        emitter.subscribe("test.echo", "sub_1")
        // Should not throw
        emitter.emit("test.echo")
        assertEquals(1, emitter.size())  // subscription still registered
    }

    @Test
    fun clearAll_resetsRegistry() {
        val (emitter, scripts) = capturingEmitter()

        emitter.subscribe("network.change", "sub_a")
        emitter.subscribe("test.echo", "sub_b")
        emitter.clearAll()
        emitter.emit("network.change")
        emitter.emit("test.echo")

        assertTrue(scripts.isEmpty())
        assertEquals(0, emitter.size())
    }

    @Test
    fun subscribe_withEmptyArgs_isRejected() {
        val (emitter, scripts) = capturingEmitter()

        emitter.subscribe("", "sub_1")
        emitter.subscribe("test.echo", "")
        emitter.emit("")

        assertEquals(0, emitter.size())
        assertTrue(scripts.isEmpty())
    }

    @Test
    fun jsStringLiteral_escapesQuotesAndBackslashes() {
        val (emitter, scripts) = capturingEmitter()

        emitter.subscribe("test.echo", "sub_1")
        // Payload containing characters that must be escaped inside a JS
        // single-quoted string.
        emitter.emit("test.echo", JsonPrimitive("it's a \\backslash test"))

        assertEquals(1, scripts.size)
        // Verify the raw value round-trips through JS string parsing intact.
        val script = scripts[0]
        assertTrue("single quote should be escaped", script.contains("it\\'s"))
        assertTrue("backslash should be escaped", script.contains("\\\\backslash"))
        assertFalse("unescaped single quote must not appear mid-string",
            script.contains("it's"))
    }

    /** Extract the subscriptionId field from the emitted JS script string. */
    private fun extractSubscriptionId(script: String): String? {
        val marker = "\"subscriptionId\":\""
        val start = script.indexOf(marker)
        if (start < 0) return null
        val valueStart = start + marker.length
        val end = script.indexOf('"', valueStart)
        return if (end < 0) null else script.substring(valueStart, end)
    }
}
