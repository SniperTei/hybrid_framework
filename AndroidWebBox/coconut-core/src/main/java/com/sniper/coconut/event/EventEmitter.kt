package com.sniper.coconut.event

import com.sniper.coconut.utils.Logger
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.util.concurrent.ConcurrentHashMap

/**
 * EventEmitter
 *
 * Manages H5 event subscriptions (one handler per topic, overwrite on second on)
 * and pushes native events to the WebView.
 *
 * Subscriptions are keyed by topic. Emit dispatches a JSON payload via the
 * registered [jsExecutor], which the host (Activity / ViewController) wires to
 * evaluateJavascript on the UI thread.
 *
 * Threading: emit() may be invoked from any thread; the jsExecutor callback
 * is responsible for hopping to the WebView thread.
 */
class EventEmitter {

    /**
     * Subscribed topics. One handler per topic (overwrite semantics).
     */
    private val topics = ConcurrentHashMap.newKeySet<String>()

    /**
     * JS execution bridge. Set by the host when the WebView is ready.
     * Receives a complete JS statement, e.g. `window.__coconutEvent('...')`.
     */
    @Volatile
    var jsExecutor: ((script: String) -> Unit)? = null

    /**
     * Register a handler for [topic]. If already subscribed, the previous
     * registration is replaced (no-op in terms of count).
     */
    fun on(topic: String) {
        if (topic.isEmpty()) {
            Logger.w(TAG, "on rejected: empty topic")
            return
        }
        val wasPresent = !topics.add(topic)
        Logger.d(TAG, "On: $topic (total=${topics.size}${if (wasPresent) ", replaced previous" else ""})")
    }

    /**
     * Remove the handler for [topic]. No-op if not present.
     */
    fun off(topic: String) {
        if (topics.remove(topic)) {
            Logger.d(TAG, "Off: $topic (total=${topics.size})")
        }
    }

    /**
     * Broadcast a [topic] event to its registered handler (if any).
     *
     * Builds the wire payload `{topic, data}` and dispatches it through
     * [jsExecutor]. If no jsExecutor is wired, the emit is silently dropped
     * (e.g. during unit tests or before WebView is ready).
     */
    fun emit(topic: String, data: JsonElement? = null) {
        if (topic.isEmpty()) {
            Logger.w(TAG, "emit rejected: empty topic")
            return
        }
        if (!topics.contains(topic)) {
            Logger.d(TAG, "emit no subscriber: $topic")
            return
        }
        dispatch(topic, data)
    }

    /**
     * Dispatch [topic] to the page regardless of native subscription state.
     *
     * Used by nav.result draining: a backgrounded container's native
     * subscription may have been wiped by clearAll() when another container
     * loaded a page, but its JS handler table is intact (the page itself
     * never reloaded), so the wire dispatch still delivers.
     */
    fun emitBypassingSubscription(topic: String, data: JsonElement? = null) {
        if (topic.isEmpty()) {
            Logger.w(TAG, "emit rejected: empty topic")
            return
        }
        dispatch(topic, data)
    }

    private fun dispatch(topic: String, data: JsonElement?) {
        val executor = jsExecutor
        if (executor == null) {
            Logger.w(TAG, "emit dropped (no jsExecutor): $topic")
            return
        }

        val payload = buildJsonObject {
            put("topic", topic)
            put("data", data ?: JsonPrimitive(null as String?))
        }
        val json = json.encodeToString(JsonObject.serializer(), payload)
        val script = "window.__coconutEvent(${jsStringLiteral(json)})"
        try {
            executor.invoke(script)
        } catch (t: Throwable) {
            Logger.e(TAG, "Failed to dispatch event for $topic", t)
        }
        Logger.d(TAG, "Emitted '$topic'")
    }

    /**
     * Clear all subscriptions. Called on page navigation (reload / new URL)
     * to prevent stale subscribers from receiving events in a fresh page context.
     */
    fun clearAll() {
        val n = topics.size
        topics.clear()
        Logger.d(TAG, "Cleared $n subscription(s)")
    }

    /**
     * Number of active subscriptions (testing / diagnostics).
     */
    fun size(): Int = topics.size

    /**
     * Whether [topic] is currently subscribed (testing / diagnostics).
     */
    fun has(topic: String): Boolean = topics.contains(topic)

    /**
     * Encode a JSON string as a JavaScript string literal.
     *
     * The payload is itself JSON, so we wrap it in single quotes and escape
     * the few characters that can break out of a single-quoted JS string.
     * Forward slash is intentionally NOT escaped (optional in JSON spec).
     */
    private fun jsStringLiteral(raw: String): String {
        val sb = StringBuilder(raw.length + 8)
        sb.append('\'')
        for (c in raw) {
            when (c) {
                '\\' -> sb.append("\\\\")
                '\'' -> sb.append("\\'")
                '\n' -> sb.append("\\n")
                '\r' -> sb.append("\\r")
                else -> sb.append(c)
            }
        }
        sb.append('\'')
        return sb.toString()
    }

    companion object {
        private const val TAG = "EventEmitter"

        /**
         * Shared JSON encoder. Configured to be lenient on encoding policies
         * since payloads are already well-formed JsonObject instances.
         */
        @OptIn(ExperimentalSerializationApi::class)
        internal val json: Json = Json {
            encodeDefaults = true
            explicitNulls = false
        }
    }
}
