import { BaseComponent } from '../component/BaseComponent';
import { BridgePerformance, MethodStats, CallRecord } from '../bridge/BridgePerformance';
import { JsonObject } from '../utils/JsonHelper';

/**
 * Performance Component
 *
 * Exposes bridge call performance metrics
 */
export class PerformanceComponent extends BaseComponent {
  name: string = 'performance';
  version: string = '1.0.0';
  description: string = 'Bridge performance monitoring component';

  async handle(functionName: string, paramsJson: string): Promise<string> {
    switch (functionName) {
      case 'getStats':
        return this.getStats();
      case 'getHistory':
        return this.getHistory(paramsJson);
      case 'resetStats':
        return this.resetStats();
      default:
        return this.functionNotSupportedError(functionName);
    }
  }

  private getStats(): string {
    const uptime = Date.now() - BridgePerformance.startTime;
    const calls = BridgePerformance.getTotalCalls();
    const successCount = BridgePerformance.getTotalSuccess();
    const statsMap = BridgePerformance.getMethodStatsMap();

    const methods: JsonObject[] = [];
    statsMap.forEach((stats: MethodStats) => {
      const builder = new JsonObject();
      builder.put('method', stats.method);
      builder.putNumber('callCount', stats.callCount);
      builder.putNumber('successCount', stats.successCount);
      builder.putNumber('failCount', stats.failCount);
      builder.putNumber('avgDuration', stats.avgDuration);
      builder.putNumber('minDuration', stats.minDuration === Number.MAX_SAFE_INTEGER ? 0 : stats.minDuration);
      builder.putNumber('maxDuration', stats.maxDuration);
      builder.put('successRate', stats.successRate.toFixed(2));
      methods.push(builder);
    });

    const root = new JsonObject();
    root.putNumber('uptimeMs', uptime);
    root.putNumber('totalCalls', calls);
    root.putNumber('totalSuccess', successCount);
    root.putNumber('totalFail', calls - successCount);
    root.put('successRate', calls > 0 ? (successCount / calls).toFixed(2) : '0.00');
    root.putNumber('methodCount', statsMap.size);
    root.putObjectArray('methods', methods);
    return this.success(root);
  }

  private getHistory(paramsJson: string): string {
    const method = this.getParam(paramsJson, 'method');
    const history = BridgePerformance.getCallHistory();

    if (method.length > 0) {
      const records = history.get(method);
      const items: JsonObject[] = [];
      if (records) {
        for (let i = 0; i < records.length; i++) {
          const record = records[i];
          const builder = new JsonObject();
          builder.put('method', record.method);
          builder.putNumber('durationMs', record.durationMs);
          builder.putBool('success', record.success);
          builder.putNumber('timestamp', record.timestamp);
          items.push(builder);
        }
      }
      const root = new JsonObject();
      root.put('method', method);
      root.putObjectArray('records', items);
      return this.success(root);
    }

    // Return all history
    const allRecords: JsonObject[] = [];
    history.forEach((records: CallRecord[], key: string) => {
      for (let i = 0; i < records.length; i++) {
        const record = records[i];
        const builder = new JsonObject();
        builder.put('method', record.method);
        builder.putNumber('durationMs', record.durationMs);
        builder.putBool('success', record.success);
        builder.putNumber('timestamp', record.timestamp);
        allRecords.push(builder);
      }
    });

    const root = new JsonObject();
    root.putNumber('totalRecords', allRecords.length);
    root.putObjectArray('records', allRecords);
    return this.success(root);
  }

  private resetStats(): string {
    BridgePerformance.resetAll();
    const builder = new JsonObject();
    builder.putBool('success', true);
    return this.success(builder);
  }
}
