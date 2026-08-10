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

    it('on_then_emit_deliversToHandler', 0, () => {
      resetScripts();
      emitter.on('test.echo');
      emitter.emit('test.echo', '{"hello":"world"}');

      expect(scripts.length).assertEqual(1);
      expect(emitter.size()).assertEqual(1);
      expect(emitter.has('test.echo')).assertTrue();
      const script = scripts[0];
      expect(script.indexOf('window.__coconutEvent') >= 0).assertTrue();
      expect(script.indexOf('"topic":"test.echo"') >= 0).assertTrue();
      expect(script.indexOf('"hello":"world"') >= 0).assertTrue();
      expect(script.indexOf('subscriptionId') < 0).assertTrue();
      emitter.off('test.echo');
    });

    it('off_blocksSubsequentEmit', 0, () => {
      resetScripts();
      emitter.on('test.echo');
      emitter.off('test.echo');
      emitter.emit('test.echo', '{}');

      expect(scripts.length).assertEqual(0);
      expect(emitter.size()).assertEqual(0);
      expect(emitter.has('test.echo')).assertFalse();
    });

    it('on_sameTopic_overwritesPreviousHandler', 0, () => {
      resetScripts();
      // First on — registers normally
      emitter.on('test.echo');
      expect(emitter.has('test.echo')).assertTrue();
      expect(emitter.size()).assertEqual(1);

      // Second on same topic — replaces previous (count stays at 1)
      emitter.on('test.echo');
      expect(emitter.size()).assertEqual(1);
      emitter.off('test.echo');
    });

    it('emit_withNoMatchingTopic_isDropped', 0, () => {
      resetScripts();
      emitter.on('network.change');
      emitter.emit('app.foreground', '{}');

      expect(scripts.length).assertEqual(0);
      emitter.off('network.change');
    });

    it('echo_roundTrip_deliversTestEchoWithPayload', 0, () => {
      resetScripts();
      emitter.on('test.echo');
      emitter.emit('test.echo', '{"hello":"world"}');

      expect(scripts.length).assertEqual(1);
      const script = scripts[0];
      expect(script.indexOf('"topic":"test.echo"') >= 0).assertTrue();
      expect(script.indexOf('"hello":"world"') >= 0).assertTrue();
      emitter.off('test.echo');
    });

    // ---- Edge cases ----

    it('emit_without_jsExecutor_isSilentlyDropped', 0, () => {
      const bareEmitter = new EventEmitter();
      bareEmitter.on('test.echo');
      bareEmitter.emit('test.echo', '{}');
      expect(bareEmitter.size()).assertEqual(1);
      expect(bareEmitter.has('test.echo')).assertTrue();
    });

    it('clearAll_resetsRegistry', 0, () => {
      resetScripts();
      emitter.on('network.change');
      emitter.on('test.echo');
      emitter.clearAll();
      emitter.emit('network.change', '{}');
      emitter.emit('test.echo', '{}');

      expect(scripts.length).assertEqual(0);
      expect(emitter.size()).assertEqual(0);
    });

    it('on_withEmptyTopic_isRejected', 0, () => {
      resetScripts();
      emitter.on('');
      emitter.emit('', '{}');

      expect(emitter.size()).assertEqual(0);
      expect(scripts.length).assertEqual(0);
    });

    it('off_withUnsubscribedTopic_isSilentNoOp', 0, () => {
      // off on a topic that was never subscribed — must not throw / crash
      emitter.off('never.subscribed');
      expect(emitter.size()).assertEqual(0);
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
