import Foundation

/**
 * EventEmitter
 *
 * Manages H5 event subscriptions (one handler per topic, overwrite on second on())
 * and pushes native events into the WebView.
 *
 * Subscriptions are keyed by topic. Emit dispatches a JSON payload through the
 * configured [JSExecutor], identical to the bridge response path.
 *
 * Thread safety: instances are @MainActor-isolated to match the rest of the
 * SDK; emit may be called from any actor / thread and dispatch hops to main.
 */
@MainActor
public final class EventEmitter {

    private let tag = "EventEmitter"
    private var topics: Set<String> = []

    /**
     * JS execution bridge. Wired by the host view controller to the WebView.
     * Nil before the WebView is ready (e.g. in unit tests).
     */
    public var jsExecutor: JSExecutor?

    /**
     * Register a handler for `topic`. Overwrites a previous handler for the
     * same topic (one handler per topic).
     */
    public func on(topic: String) {
        guard !topic.isEmpty else {
            Logger.shared.w(tag, "on rejected: empty topic")
            return
        }
        let wasPresent = topics.contains(topic)
        topics.insert(topic)
        Logger.shared.d(tag, "On: \(topic) (total=\(topics.count)\(wasPresent ? ", replaced previous" : ""))")
    }

    /**
     * Remove the handler for `topic`. No-op if not present.
     */
    public func off(topic: String) {
        if topics.remove(topic) != nil {
            Logger.shared.d(tag, "Off: \(topic) (total=\(topics.count))")
        }
    }

    /**
     * Broadcast a `topic` event to its registered handler (if any).
     *
     * The handler receives a JSON payload of shape `{topic, data}` and is
     * dispatched via `window.__coconutEvent('<json>')`. If no jsExecutor is
     * wired, the emit is silently dropped.
     */
    public func emit(topic: String, data: Any? = nil) {
        guard !topic.isEmpty else {
            Logger.shared.w(tag, "emit rejected: empty topic")
            return
        }
        guard topics.contains(topic) else {
            Logger.shared.d(tag, "emit no subscriber: \(topic)")
            return
        }
        dispatch(topic: topic, data: data)
    }

    /**
     * Emit bypassing the native subscription gate. Used for `nav.result`
     * delivery on container resume: the closing child's page load may have
     * clearAll()'d our native registration, but this page's own JS handler
     * table (coconut.on) is intact.
     */
    public func emitBypassingSubscription(topic: String, data: Any? = nil) {
        guard !topic.isEmpty else {
            Logger.shared.w(tag, "emit rejected: empty topic")
            return
        }
        dispatch(topic: topic, data: data)
    }

    private func dispatch(topic: String, data: Any?) {
        guard let executor = jsExecutor else {
            Logger.shared.w(tag, "emit dropped (no jsExecutor): \(topic)")
            return
        }

        let payload: [String: Any] = [
            "topic": topic,
            "data": data ?? NSNull(),
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else {
            Logger.shared.e(tag, "Failed to encode payload for \(topic)")
            return
        }

        let escaped = Self.escapeJSString(json)
        let script = "window.__coconutEvent('\(escaped)')"

        Task { [weak self] in
            let error = await executor.evaluateJavaScript(script)
            if let error = error {
                Logger.shared.e(self?.tag ?? "EventEmitter",
                                "Failed to dispatch event for \(topic)",
                                error)
            }
        }
        Logger.shared.d(tag, "Emitted '\(topic)' (bypass=\(topics.contains(topic) ? "no" : "yes"))")
    }

    /**
     * Clear all subscriptions. Called on page navigation (reload / new URL)
     * to prevent stale subscribers from receiving events in a fresh page context.
     */
    public func clearAll() {
        let n = topics.count
        topics.removeAll()
        Logger.shared.d(tag, "Cleared \(n) subscription(s)")
    }

    /// Active subscription count (testing / diagnostics).
    public var count: Int { topics.count }

    /// Whether `topic` is currently subscribed (testing / diagnostics).
    public func has(topic: String) -> Bool { topics.contains(topic) }

    /**
     * Escape a raw JSON string for safe embedding inside a single-quoted
     * JavaScript string literal. Mirrors `BridgeResponseSender.sendResponse`.
     */
    static func escapeJSString(_ raw: String) -> String {
        return raw
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
}
