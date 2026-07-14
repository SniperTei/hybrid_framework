import { BaseComponent, BridgePerformance, MethodStats, CallRecord, JsonObject } from '@coconut/sdk';

/**
 * Performance Component
 *
 * Exposes bridge call performance metrics.
 * Method names aligned with iOS/Android contract:
 *   getMetrics / getMethodStats / getSlowCalls / reset
 */
export class PerformanceComponent extends BaseComponent {
  name: string = 'performance';
  version: string = '1.0.0';
  description: string = 'Bridge performance monitoring component';

  async handle(functionName: string, paramsJson: string): Promise<string> {
    switch (functionName) {
      case 'getMetrics':
        return this.getMetrics();
      case 'getMethodStats':
        return this.getMethodStats(paramsJson);
      case 'getSlowCalls':
        return this.getSlowCalls(paramsJson);
      case 'reset':
        return this.reset();
      default:
        return this.functionNotSupportedError(functionName);
    }
  }

  private getMetrics(): string {
    const uptime = Date.now() - BridgePerformance.startTime;
    const calls = BridgePerformance.getTotalCalls();
    const successCount = BridgePerformance.getTotalSuccess();
    const methodCount = BridgePerformance.getMethodStatsMap().size;

    const root = new JsonObject();
    root.putNumber('uptimeMs', uptime);
    root.putNumber('totalCalls', calls);
    root.putNumber('totalSuccess', successCount);
    root.putNumber('totalFail', calls - successCount);
    root.put('successRate', calls > 0 ? (successCount / calls).toFixed(2) : '0.00');
    root.putNumber('methodCount', methodCount);
    return this.success(root);
  }

  private getMethodStats(paramsJson: string): string {
    const method = this.getParam(paramsJson, 'method');
    const all = this.getBoolParam(paramsJson, 'all', false);
    const statsMap = BridgePerformance.getMethodStatsMap();

    // No method specified, or all=true → return list of all methods
    if (all || method.length === 0) {
      const methods: JsonObject[] = [];
      statsMap.forEach((stats: MethodStats) => {
        methods.push(this.buildMethodStats(stats));
      });

      const root = new JsonObject();
      root.putObjectArray('methods', methods);
      return this.success(root);
    }

    // Specific method requested
    const stats = statsMap.get(method);
    if (!stats) {
      const root = new JsonObject();
      root.put('method', method);
      root.putNumber('callCount', 0);
      return this.success(root);
    }

    return this.success(this.buildMethodStats(stats));
  }

  private getSlowCalls(paramsJson: string): string {
    const threshold = this.getIntParam(paramsJson, 'threshold', 500);
    const history = BridgePerformance.getCallHistory();

    // Collect all records, filter by threshold, sort desc, take 50
    const allRecords: CallRecord[] = [];
    history.forEach((records: CallRecord[]) => {
      for (let i = 0; i < records.length; i++) {
        allRecords.push(records[i]);
      }
    });

    const slowCalls = allRecords
      .filter((r: CallRecord) => r.durationMs > threshold)
      .sort((a: CallRecord, b: CallRecord) => b.durationMs - a.durationMs)
      .slice(0, 50);

    const items: JsonObject[] = [];
    for (let i = 0; i < slowCalls.length; i++) {
      const record = slowCalls[i];
      const builder = new JsonObject();
      builder.put('method', record.method);
      builder.putNumber('durationMs', record.durationMs);
      builder.putBool('success', record.success);
      builder.putNumber('timestamp', record.timestamp);
      items.push(builder);
    }

    const root = new JsonObject();
    root.putNumber('threshold', threshold);
    root.putNumber('slowCallCount', slowCalls.length);
    root.putObjectArray('slowCalls', items);
    return this.success(root);
  }

  private reset(): string {
    BridgePerformance.resetAll();
    const builder = new JsonObject();
    builder.putBool('success', true);
    return this.success(builder);
  }

  private buildMethodStats(stats: MethodStats): JsonObject {
    const builder = new JsonObject();
    builder.put('method', stats.method);
    builder.putNumber('callCount', stats.callCount);
    builder.putNumber('successCount', stats.successCount);
    builder.putNumber('failCount', stats.failCount);
    builder.putNumber('avgDuration', stats.avgDuration);
    builder.putNumber('minDuration', stats.minDuration === Number.MAX_SAFE_INTEGER ? 0 : stats.minDuration);
    builder.putNumber('maxDuration', stats.maxDuration);
    builder.put('successRate', stats.successRate.toFixed(2));
    return builder;
  }
}
