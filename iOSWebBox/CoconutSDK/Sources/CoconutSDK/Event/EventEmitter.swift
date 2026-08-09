import Foundation

/// One H5 subscription registration (topic + id).
public struct Subscription: Equatable {
    public let subscriptionId: String
    public let topic: String
}

/**
 * EventEmitter
 *
 * Manages H5 event subscriptions and pushes native events into the WebView.
 *
 * Subscriptions are keyed by subscriptionId (generated client-side by H5 to
 * eliminate the async response window race). Emit dispatches a JSON payload
 * through the configured [JSExecutor], identical to the bridge response path.
 *
 * Thread safety: instances are @MainActor-isolated to match the rest of the
 * SDK; emit may be called from any actor / thread and dispatch hops to main.
 */
@MainActor
public final class EventEmitter {

    private let tag = "EventEmitter"
    private var subscriptions: [String: Subscription] = [:]

    /**
     * JS execution bridge. Wired by the host view controller to the WebView.
     * Nil before the WebView is ready (e.g. in unit tests).
     */
    public var jsExecutor: JSExecutor?

    /**
     * Register a subscription for `topic` under `subscriptionId`.
     * Overwrites an existing entry with the same id.
     */
    public func subscribe(topic: String, subscriptionId: String) {
        guard !topic.isEmpty, !subscriptionId.isEmpty else {
            Logger.shared.w(tag, "subscribe rejected: empty topic or subscriptionId")
            return
        }
        subscriptions[subscriptionId] = Subscription(subscriptionId: subscriptionId, topic: topic)
        Logger.shared.d(tag, "Subscribed: \(subscriptionId) -> \(topic) (total=\(subscriptions.count))")
    }

    /**
     * Remove a subscription by id. No-op if not present.
     */
    public func unsubscribe(subscriptionId: String) {
        if let removed = subscriptions.removeValue(forKey: subscriptionId) {
            Logger.shared.d(tag, "Unsubscribed: \(removed.subscriptionId) (total=\(subscriptions.count))")
        }
    }

    /**
     * Broadcast a `topic` event to all matching subscribers.
     *
     * Each subscriber receives its own payload (containing its own
     * subscriptionId) and is dispatched via `window.__coconutEvent('<json>')`.
     * If no jsExecutor is wired, the emit is silently dropped.
     */
    public func emit(topic: String, data: Any? = nil) {
        guard !topic.isEmpty else {
            Logger.shared.w(tag, "emit rejected: empty topic")
            return
        }
        guard let executor = jsExecutor else {
            Logger.shared.w(tag, "emit dropped (no jsExecutor): \(topic)")
            return
        }

        let matches = subscriptions.values.filter { $0.topic == topic }
        guard !matches.isEmpty else {
            Logger.shared.d(tag, "emit no subscribers: \(topic)")
            return
        }

        for sub in matches {
            let payload: [String: Any] = [
                "subscriptionId": sub.subscriptionId,
                "topic": topic,
                "data": data ?? NSNull(),
            ]

            guard let data = try? JSONSerialization.data(withJSONObject: payload),
                  let json = String(data: data, encoding: .utf8) else {
                Logger.shared.e(tag, "Failed to encode payload for \(sub.subscriptionId)")
                continue
            }

            let escaped = Self.escapeJSString(json)
            let script = "window.__coconutEvent('\(escaped)')"

            Task { [weak self] in
                let error = await executor.evaluateJavaScript(script)
                if let error = error {
                    Logger.shared.e(self?.tag ?? "EventEmitter",
                                    "Failed to dispatch event to \(sub.subscriptionId)",
                                    error)
                }
            }
        }
        Logger.shared.d(tag, "Emitted '\(topic)' to \(matches.count) subscriber(s)")
    }

    /**
     * Clear all subscriptions. Called on page navigation (reload / new URL)
     * to prevent stale subscribers from receiving events in a fresh page context.
     */
    public func clearAll() {
        let n = subscriptions.count
        subscriptions.removeAll()
        Logger.shared.d(tag, "Cleared \(n) subscription(s)")
    }

    /// Active subscription count (testing / diagnostics).
    public var count: Int { subscriptions.count }

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
