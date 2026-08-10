import { Logger } from '../utils/Logger';
import { JsonObject } from '../utils/JsonHelper';

/**
 * Signature of the JS dispatch callback. Receives a fully-formed JS
 * statement like `window.__coconutEvent('...')`. The host wires this to
 * `webController.runJavaScript(script)`.
 */
export type JsExecutor = (script: string) => void;

/**
 * EventEmitter
 *
 * Manages H5 event subscriptions (one handler per topic, overwrite on
 * second on) and pushes native events into the WebView.
 *
 * Subscriptions are keyed by topic. Emit dispatches a JSON payload
 * through the registered [jsExecutor].
 */
export class EventEmitter {
  private readonly TAG: string = 'EventEmitter';
  private topics: Set<string> = new Set();
  private executor: JsExecutor | null = null;

  /**
   * Wire the JS dispatch callback. Called by the host page once the
   * WebView controller is ready.
   */
  setJsExecutor(executor: JsExecutor): void {
    this.executor = executor;
  }

  /**
   * Register a handler for `topic`. If already subscribed, the previous
   * registration is replaced (no-op in terms of count).
   */
  on(topic: string): void {
    if (topic.length === 0) {
      Logger.w(this.TAG, 'on rejected: empty topic');
      return;
    }
    const wasPresent: boolean = this.topics.has(topic);
    this.topics.add(topic);
    Logger.d(this.TAG, `On: ${topic} (total=${this.topics.size}${wasPresent ? ', replaced previous' : ''})`);
  }

  /**
   * Remove the handler for `topic`. No-op if not present.
   */
  off(topic: string): void {
    if (this.topics.delete(topic)) {
      Logger.d(this.TAG, `Off: ${topic} (total=${this.topics.size})`);
    }
  }

  /**
   * Broadcast a `topic` event to its registered handler (if any).
   *
   * Builds the wire payload `{topic, data}` and dispatches it via
   * `window.__coconutEvent('<json>')`. If no jsExecutor is wired, the
   * emit is silently dropped.
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
    if (!this.topics.has(topic)) {
      Logger.d(this.TAG, `emit no subscriber: ${topic}`);
      return;
    }

    const dataField = dataJson.length > 0 ? dataJson : 'null';
    const builder = new JsonObject();
    builder.put('topic', topic);
    builder.putJson('data', dataField);
    const json = builder.build();
    const escaped = EventEmitter.escapeJsString(json);
    const script = `window.__coconutEvent && window.__coconutEvent('${escaped}')`;
    try {
      (this.executor as JsExecutor)(script);
    } catch (e) {
      Logger.e(this.TAG, `Failed to dispatch event for ${topic}: ${e}`);
    }
    Logger.d(this.TAG, `Emitted '${topic}'`);
  }

  /**
   * Clear all subscriptions. Called on page navigation (reload / new URL)
   * to prevent stale subscribers from receiving events in a fresh page context.
   */
  clearAll(): void {
    const n = this.topics.size;
    this.topics.clear();
    Logger.d(this.TAG, `Cleared ${n} subscription(s)`);
  }

  /**
   * Number of active subscriptions (testing / diagnostics).
   */
  size(): number {
    return this.topics.size;
  }

  /**
   * Whether `topic` is currently subscribed (testing / diagnostics).
   */
  has(topic: string): boolean {
    return this.topics.has(topic);
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
