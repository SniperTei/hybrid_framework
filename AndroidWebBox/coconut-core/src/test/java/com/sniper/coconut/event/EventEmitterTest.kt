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
    fun on_then_emit_deliversToHandler() {
        val (emitter, scripts) = capturingEmitter()

        emitter.on("test.echo")
        emitter.emit("test.echo", buildJsonObject { put("hello", "world") })

        assertEquals(1, scripts.size)
        assertEquals(1, emitter.size())
        assertTrue(emitter.has("test.echo"))
        // Script shape: window.__coconutEvent('...json...')
        assertTrue("script should call __coconutEvent", scripts[0].startsWith("window.__coconutEvent('"))
        assertTrue("script should contain topic", scripts[0].contains("\"topic\":\"test.echo\""))
        assertFalse("payload should not contain subscriptionId",
            scripts[0].contains("subscriptionId"))
        assertTrue("script should contain data", scripts[0].contains("\"hello\":\"world\""))
    }

    @Test
    fun off_blocksSubsequentEmit() {
        val (emitter, scripts) = capturingEmitter()

        emitter.on("test.echo")
        emitter.off("test.echo")
        emitter.emit("test.echo")

        assertTrue("no script should be dispatched after off", scripts.isEmpty())
        assertEquals(0, emitter.size())
        assertFalse(emitter.has("test.echo"))
    }

    @Test
    fun on_sameTopic_overwritesPreviousHandler() {
        val (emitter, _) = capturingEmitter()

        // First on — registers normally
        emitter.on("test.echo")
        assertTrue(emitter.has("test.echo"))
        assertEquals(1, emitter.size())

        // Second on same topic — replaces previous (count stays at 1)
        emitter.on("test.echo")
        assertEquals(1, emitter.size())
    }

    @Test
    fun emit_withNoMatchingTopic_isDropped() {
        val (emitter, scripts) = capturingEmitter()

        emitter.on("network.change")
        emitter.emit("app.foreground")  // different topic

        assertTrue(scripts.isEmpty())
    }

    @Test
    fun echo_roundTrip_deliversTestEchoWithPayload() {
        val (emitter, scripts) = capturingEmitter()

        emitter.on("test.echo")
        emitter.emit("test.echo", buildJsonObject { put("hello", "world") })

        assertEquals(1, scripts.size)
        assertTrue(scripts[0].contains("\"topic\":\"test.echo\""))
        assertTrue(scripts[0].contains("\"hello\":\"world\""))
    }

    // ---- Edge cases ----

    @Test
    fun emit_without_jsExecutor_isSilentlyDropped() {
        val emitter = EventEmitter()  // no jsExecutor
        emitter.on("test.echo")
        // Should not throw
        emitter.emit("test.echo")
        assertEquals(1, emitter.size())  // subscription still registered
    }

    @Test
    fun clearAll_resetsRegistry() {
        val (emitter, scripts) = capturingEmitter()

        emitter.on("network.change")
        emitter.on("test.echo")
        emitter.clearAll()
        emitter.emit("network.change")
        emitter.emit("test.echo")

        assertTrue(scripts.isEmpty())
        assertEquals(0, emitter.size())
    }

    @Test
    fun on_withEmptyTopic_isRejected() {
        val (emitter, scripts) = capturingEmitter()

        emitter.on("")
        emitter.emit("")

        assertEquals(0, emitter.size())
        assertTrue(scripts.isEmpty())
    }

    @Test
    fun off_withUnsubscribedTopic_isSilentNoOp() {
        val (emitter, _) = capturingEmitter()

        // off on a topic that was never subscribed — must not throw / crash
        emitter.off("never.subscribed")
        assertEquals(0, emitter.size())
    }

    @Test
    fun jsStringLiteral_escapesQuotesAndBackslashes() {
        val (emitter, scripts) = capturingEmitter()

        emitter.on("test.echo")
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
}
