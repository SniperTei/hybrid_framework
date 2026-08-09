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
 * Event Subscription Record
 */
data class Subscription(
    val subscriptionId: String,
    val topic: String
)

/**
 * EventEmitter
 *
 * Manages H5 event subscriptions and pushes native events to the WebView.
 *
 * Subscriptions are keyed by subscriptionId (generated client-side by H5 to
 * eliminate the async response window race present on iOS/Harmony). Emit
 * dispatches a JSON payload via the registered [jsExecutor], which the host
 * (Activity / ViewController) wires to evaluateJavascript on the UI thread.
 *
 * Threading: emit() may be invoked from any thread; the jsExecutor callback
 * is responsible for hopping to the WebView thread.
 */
class EventEmitter {

    /**
     * Subscriptions keyed by subscriptionId.
     */
    private val subscriptions = ConcurrentHashMap<String, Subscription>()

    /**
     * JS execution bridge. Set by the host when the WebView is ready.
     * Receives a complete JS statement, e.g. `window.__coconutEvent('...')`.
     */
    @Volatile
    var jsExecutor: ((script: String) -> Unit)? = null

    /**
     * Register a subscription for [topic] under [subscriptionId].
     * If [subscriptionId] already exists, it is overwritten.
     */
    fun subscribe(topic: String, subscriptionId: String) {
        if (topic.isEmpty() || subscriptionId.isEmpty()) {
            Logger.w(TAG, "subscribe rejected: empty topic or subscriptionId")
            return
        }
        subscriptions[subscriptionId] = Subscription(subscriptionId, topic)
        Logger.d(TAG, "Subscribed: $subscriptionId -> $topic (total=${subscriptions.size})")
    }

    /**
     * Remove a subscription by id. No-op if not present.
     */
    fun unsubscribe(subscriptionId: String) {
        val removed = subscriptions.remove(subscriptionId)
        if (removed != null) {
            Logger.d(TAG, "Unsubscribed: $subscriptionId (total=${subscriptions.size})")
        }
    }

    /**
     * Broadcast a [topic] event to all matching subscribers.
     *
     * Builds the wire payload `{subscriptionId, topic, data}` per subscriber
     * (so each subscriber receives its own subscriptionId) and dispatches
     * each through [jsExecutor]. If no jsExecutor is wired, the emit is
     * silently dropped (e.g. during unit tests or before WebView is ready).
     */
    fun emit(topic: String, data: JsonElement? = null) {
        if (topic.isEmpty()) {
            Logger.w(TAG, "emit rejected: empty topic")
            return
        }
        val executor = jsExecutor
        if (executor == null) {
            Logger.w(TAG, "emit dropped (no jsExecutor): $topic")
            return
        }

        // Snapshot matching subscribers (avoid CME / mutation during iteration)
        val matches = subscriptions.values.filter { it.topic == topic }
        if (matches.isEmpty()) {
            Logger.d(TAG, "emit no subscribers: $topic")
            return
        }

        for (sub in matches) {
            val payload = buildJsonObject {
                put("subscriptionId", sub.subscriptionId)
                put("topic", topic)
                put("data", data ?: JsonPrimitive(null as String?))
            }
            val json = json.encodeToString(JsonObject.serializer(), payload)
            val script = "window.__coconutEvent(${jsStringLiteral(json)})"
            try {
                executor.invoke(script)
            } catch (t: Throwable) {
                Logger.e(TAG, "Failed to dispatch event to ${sub.subscriptionId}", t)
            }
        }
        Logger.d(TAG, "Emitted '$topic' to ${matches.size} subscriber(s)")
    }

    /**
     * Clear all subscriptions. Called on page navigation (reload / new URL)
     * to prevent stale subscribers from receiving events in a fresh page context.
     */
    fun clearAll() {
        val n = subscriptions.size
        subscriptions.clear()
        Logger.d(TAG, "Cleared $n subscription(s)")
    }

    /**
     * Number of active subscriptions (testing / diagnostics).
     */
    fun size(): Int = subscriptions.size

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
