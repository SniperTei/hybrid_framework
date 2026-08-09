import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium';
import { EventEmitter } from '@coconut/sdk';

/**
 * Shared scratchpad for the capturing executor. Reset between tests via
 * resetScripts().
 */
let scripts: string[] = [];

function resetScripts(): void {
  scripts = [];
}

function captureExecutor(script: string): void {
  scripts.push(script);
}

function extractSubscriptionId(script: string): string {
  const marker = '"subscriptionId":"';
  const start = script.indexOf(marker);
  if (start < 0) {
    return '';
  }
  const valueStart = start + marker.length;
  const valueEnd = script.indexOf('"', valueStart);
  return valueEnd < 0 ? '' : script.substring(valueStart, valueEnd);
}

/**
 * Unit tests for EventEmitter.
 *
 * Uses a capturing jsExecutor to assert the exact JS payload that would be
 * dispatched to the WebView. Real WebView integration is exercised by the
 * demo app's coconut_index.html page.
 */
export default function eventEmitterTest() {
  describe('EventEmitter', () => {
    let emitter: EventEmitter = new EventEmitter();

    beforeAll(() => {
      emitter.setJsExecutor(captureExecutor);
    });

    afterAll(() => {
      emitter.clearAll();
    });

    // ---- Core cases ----

    it('subscribe_then_emit_deliversToSubscriber', 0, () => {
      resetScripts();
      emitter.subscribe('test.echo', 'sub_1');
      emitter.emit('test.echo', '{"hello":"world"}');

      expect(scripts.length).assertEqual(1);
      const script = scripts[0];
      expect(script.indexOf('window.__coconutEvent') >= 0).assertTrue();
      expect(script.indexOf('"topic":"test.echo"') >= 0).assertTrue();
      expect(script.indexOf('"subscriptionId":"sub_1"') >= 0).assertTrue();
      expect(script.indexOf('"hello":"world"') >= 0).assertTrue();
      expect(emitter.size()).assertEqual(1);
      emitter.unsubscribe('sub_1');
    });

    it('unsubscribe_blocksSubsequentEmit', 0, () => {
      resetScripts();
      emitter.subscribe('test.echo', 'sub_1');
      emitter.unsubscribe('sub_1');
      emitter.emit('test.echo', '{}');

      expect(scripts.length).assertEqual(0);
      expect(emitter.size()).assertEqual(0);
    });

    it('multiple_subscribers_for_same_topic_allReceive', 0, () => {
      resetScripts();
      emitter.subscribe('network.change', 'sub_a');
      emitter.subscribe('network.change', 'sub_b');
      emitter.emit('network.change', '42');

      expect(scripts.length).assertEqual(2);
      const ids: string[] = [];
      for (let i = 0; i < scripts.length; i++) {
        ids.push(extractSubscriptionId(scripts[i]));
        expect(scripts[i].indexOf('"data":42') >= 0).assertTrue();
      }
      expect(ids.indexOf('sub_a') >= 0).assertTrue();
      expect(ids.indexOf('sub_b') >= 0).assertTrue();
      emitter.unsubscribe('sub_a');
      emitter.unsubscribe('sub_b');
    });

    it('emit_withNoMatchingTopic_isDropped', 0, () => {
      resetScripts();
      emitter.subscribe('network.change', 'sub_a');
      emitter.emit('app.foreground', '{}');

      expect(scripts.length).assertEqual(0);
      emitter.unsubscribe('sub_a');
    });

    it('echo_roundTrip_deliversTestEchoWithPayload', 0, () => {
      resetScripts();
      emitter.subscribe('test.echo', 'sub_echo');
      emitter.emit('test.echo', '{"hello":"world"}');

      expect(scripts.length).assertEqual(1);
      const script = scripts[0];
      expect(script.indexOf('"topic":"test.echo"') >= 0).assertTrue();
      expect(script.indexOf('"hello":"world"') >= 0).assertTrue();
      emitter.unsubscribe('sub_echo');
    });

    // ---- Edge cases ----

    it('emit_without_jsExecutor_isSilentlyDropped', 0, () => {
      const bareEmitter = new EventEmitter();
      bareEmitter.subscribe('test.echo', 'sub_1');
      bareEmitter.emit('test.echo', '{}');
      expect(bareEmitter.size()).assertEqual(1);
    });

    it('clearAll_resetsRegistry', 0, () => {
      resetScripts();
      emitter.subscribe('network.change', 'sub_a');
      emitter.subscribe('test.echo', 'sub_b');
      emitter.clearAll();
      emitter.emit('network.change', '{}');
      emitter.emit('test.echo', '{}');

      expect(scripts.length).assertEqual(0);
      expect(emitter.size()).assertEqual(0);
    });

    it('subscribe_withEmptyArgs_isRejected', 0, () => {
      resetScripts();
      emitter.subscribe('', 'sub_1');
      emitter.subscribe('test.echo', '');
      emitter.emit('', '{}');

      expect(emitter.size()).assertEqual(0);
      expect(scripts.length).assertEqual(0);
    });

    it('escapeJsString_handlesQuotesAndBackslashes', 0, () => {
      const raw = "it's a \\backslash\nnewline";
      const escaped = EventEmitter.escapeJsString(raw);
      expect(escaped.indexOf("it\\'s") >= 0).assertTrue();
      expect(escaped.indexOf("\\\\backslash") >= 0).assertTrue();
      expect(escaped.indexOf("\\n") >= 0).assertTrue();
    });
  });
}
