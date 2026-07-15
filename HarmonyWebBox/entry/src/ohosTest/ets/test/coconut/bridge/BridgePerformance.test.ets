import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium';
import { BridgePerformance } from '@coconut/sdk';

export default function bridgePerformanceTest() {
  describe('BridgePerformance', () => {
    beforeAll(() => {
      BridgePerformance.resetAll();
    });

    afterAll(() => {
      BridgePerformance.resetAll();
    });

    it('record_incrementsTotalCalls', 0, () => {
      BridgePerformance.resetAll();
      BridgePerformance.record('device.getInfo', 10, true);
      BridgePerformance.record('device.getInfo', 20, false);
      expect(BridgePerformance.getTotalCalls()).assertEqual(2);
      expect(BridgePerformance.getTotalSuccess()).assertEqual(1);
    });

    it('getMethodStatsMap_returnsPerMethodStats', 0, () => {
      BridgePerformance.resetAll();
      BridgePerformance.record('a.run', 5, true);
      BridgePerformance.record('a.run', 15, true);
      BridgePerformance.record('b.run', 7, false);
      const stats = BridgePerformance.getMethodStatsMap();
      const a = stats.get('a.run');
      expect(a !== undefined).assertTrue();
      expect(a!.callCount).assertEqual(2);
      expect(a!.successCount).assertEqual(2);
      expect(a!.failCount).assertEqual(0);
      expect(a!.avgDuration).assertEqual(10);
      const b = stats.get('b.run');
      expect(b !== undefined).assertTrue();
      expect(b!.failCount).assertEqual(1);
    });

    it('stats_tracksMinMaxDuration', 0, () => {
      BridgePerformance.resetAll();
      BridgePerformance.record('m.x', 5, true);
      BridgePerformance.record('m.x', 50, true);
      BridgePerformance.record('m.x', 25, true);
      const stats = BridgePerformance.getMethodStatsMap().get('m.x')!;
      expect(stats.minDuration).assertEqual(5);
      expect(stats.maxDuration).assertEqual(50);
    });

    it('resetAll_clearsEverything', 0, () => {
      BridgePerformance.record('temp.run', 1, true);
      expect(BridgePerformance.getTotalCalls() > 0).assertTrue();
      BridgePerformance.resetAll();
      expect(BridgePerformance.getTotalCalls()).assertEqual(0);
      expect(BridgePerformance.getTotalSuccess()).assertEqual(0);
      expect(BridgePerformance.getMethodStatsMap().size).assertEqual(0);
    });

    it('record_manyCalls_doesNotCrash', 0, () => {
      BridgePerformance.resetAll();
      for (let i = 0; i < 200; i++) {
        BridgePerformance.record('burst.method', i, i % 2 === 0);
      }
      expect(BridgePerformance.getTotalCalls()).assertEqual(200);
      expect(BridgePerformance.getTotalSuccess()).assertEqual(100);
      // History is capped at MAX_HISTORY_PER_METHOD=100.
      const history = BridgePerformance.getCallHistory().get('burst.method')!;
      expect(history.length).assertEqual(100);
    });
  });
}
