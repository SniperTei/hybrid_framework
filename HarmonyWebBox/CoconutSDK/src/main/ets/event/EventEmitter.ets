import { Logger } from '../utils/Logger';
import { JsonObject } from '../utils/JsonHelper';

/**
 * One H5 subscription registration (topic + id).
 */
export interface Subscription {
  subscriptionId: string;
  topic: string;
}

/**
 * Signature of the JS dispatch callback. Receives a fully-formed JS
 * statement like `window.__coconutEvent('...')`. The host wires this to
 * `webController.runJavaScript(script)`.
 */
export type JsExecutor = (script: string) => void;

/**
 * EventEmitter
 *
 * Manages H5 event subscriptions and pushes native events into the WebView.
 *
 * Subscriptions are keyed by subscriptionId (generated client-side by H5 to
 * eliminate the async response window race). Emit dispatches a JSON payload
 * through the registered [jsExecutor].
 */
export class EventEmitter {
  private readonly TAG: string = 'EventEmitter';
  private subscriptions: Map<string, Subscription> = new Map();
  private executor: JsExecutor | null = null;

  /**
   * Wire the JS dispatch callback. Called by the host page once the
   * WebView controller is ready.
   */
  setJsExecutor(executor: JsExecutor): void {
    this.executor = executor;
  }

  /**
   * Register a subscription for `topic` under `subscriptionId`.
   * Overwrites an existing entry with the same id.
   */
  subscribe(topic: string, subscriptionId: string): void {
    if (topic.length === 0 || subscriptionId.length === 0) {
      Logger.w(this.TAG, 'subscribe rejected: empty topic or subscriptionId');
      return;
    }
    const sub: Subscription = { subscriptionId, topic };
    this.subscriptions.set(subscriptionId, sub);
    Logger.d(this.TAG, `Subscribed: ${subscriptionId} -> ${topic} (total=${this.subscriptions.size})`);
  }

  /**
   * Remove a subscription by id. No-op if not present.
   */
  unsubscribe(subscriptionId: string): void {
    if (this.subscriptions.has(subscriptionId)) {
      this.subscriptions.delete(subscriptionId);
      Logger.d(this.TAG, `Unsubscribed: ${subscriptionId} (total=${this.subscriptions.size})`);
    }
  }

  /**
   * Broadcast a `topic` event to all matching subscribers.
   *
   * Each subscriber receives its own payload (containing its own
   * subscriptionId) and is dispatched via `window.__coconutEvent('<json>')`.
   * If no jsExecutor is wired, the emit is silently dropped.
   *
   * `dataJson` is an arbitrary JSON string (object / array / primitive).
   * If empty, `null` is emitted.
   */
  emit(topic: string, dataJson: string = ''): void {
    if (topic.length === 0) {
      Logger.w(this.TAG, 'emit rejected: empty topic');
      return;
    }
    if (this.executor === null) {
      Logger.w(this.TAG, `emit dropped (no jsExecutor): ${topic}`);
      return;
    }

    // Snapshot matching subscribers.
    const matches: Subscription[] = [];
    this.subscriptions.forEach((sub: Subscription) => {
      if (sub.topic === topic) {
        matches.push(sub);
      }
    });
    if (matches.length === 0) {
      Logger.d(this.TAG, `emit no subscribers: ${topic}`);
      return;
    }

    const dataField = dataJson.length > 0 ? dataJson : 'null';

    for (let i = 0; i < matches.length; i++) {
      const sub = matches[i];
      const builder = new JsonObject();
      builder.put('subscriptionId', sub.subscriptionId);
      builder.put('topic', topic);
      builder.putJson('data', dataField);
      const json = builder.build();
      const escaped = EventEmitter.escapeJsString(json);
      const script = `window.__coconutEvent && window.__coconutEvent('${escaped}')`;
      try {
        (this.executor as JsExecutor)(script);
      } catch (e) {
        Logger.e(this.TAG, `Failed to dispatch event to ${sub.subscriptionId}: ${e}`);
      }
    }
    Logger.d(this.TAG, `Emitted '${topic}' to ${matches.length} subscriber(s)`);
  }

  /**
   * Clear all subscriptions. Called on page navigation (reload / new URL)
   * to prevent stale subscribers from receiving events in a fresh page context.
   */
  clearAll(): void {
    const n = this.subscriptions.size;
    this.subscriptions.clear();
    Logger.d(this.TAG, `Cleared ${n} subscription(s)`);
  }

  /**
   * Number of active subscriptions (testing / diagnostics).
   */
  size(): number {
    return this.subscriptions.size;
  }

  /**
   * Escape a raw string for safe embedding inside a single-quoted
   * JavaScript string literal. Mirrors CoconutBridgeImpl.sendResponse.
   */
  static escapeJsString(raw: string): string {
    return raw
      .replace(/\\/g, '\\\\')
      .replace(/'/g, "\\'")
      .replace(/\n/g, '\\n')
      .replace(/\r/g, '\\r');
  }
}
