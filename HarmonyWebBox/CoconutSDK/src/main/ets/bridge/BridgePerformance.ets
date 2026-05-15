/**
 * Bridge Performance Collector
 *
 * Records bridge call metrics for monitoring
 */
export interface CallRecord {
  method: string;
  durationMs: number;
  success: boolean;
  timestamp: number;
}

export interface MethodStats {
  method: string;
  callCount: number;
  successCount: number;
  failCount: number;
  totalDuration: number;
  minDuration: number;
  maxDuration: number;
  avgDuration: number;
  successRate: number;
}

export class BridgePerformance {
  private static callHistory: Map<string, CallRecord[]> = new Map();
  private static methodStatsMap: Map<string, MethodStats> = new Map();
  private static totalCalls: number = 0;
  private static totalSuccess: number = 0;
  private static readonly MAX_HISTORY_PER_METHOD = 100;
  static startTime: number = Date.now();

  static record(method: string, durationMs: number, success: boolean): void {
    BridgePerformance.totalCalls++;
    if (success) BridgePerformance.totalSuccess++;

    // Update method stats
    let stats = BridgePerformance.methodStatsMap.get(method);
    if (!stats) {
      stats = new MethodStatsImpl();
      stats.method = method;
      stats.callCount = 0;
      stats.successCount = 0;
      stats.failCount = 0;
      stats.totalDuration = 0;
      stats.minDuration = Number.MAX_SAFE_INTEGER;
      stats.maxDuration = 0;
      stats.avgDuration = 0;
      stats.successRate = 0;
      BridgePerformance.methodStatsMap.set(method, stats);
    }

    stats.callCount++;
    if (success) {
      stats.successCount++;
    } else {
      stats.failCount++;
    }
    stats.totalDuration += durationMs;
    stats.minDuration = Math.min(stats.minDuration, durationMs);
    stats.maxDuration = Math.max(stats.maxDuration, durationMs);
    stats.avgDuration = Math.round(stats.totalDuration / stats.callCount);
    stats.successRate = stats.callCount > 0 ? stats.successCount / stats.callCount : 0;

    // Update history
    let history = BridgePerformance.callHistory.get(method);
    if (!history) {
      history = [];
      BridgePerformance.callHistory.set(method, history);
    }
    const record = new CallRecordImpl();
    record.method = method;
    record.durationMs = durationMs;
    record.success = success;
    record.timestamp = Date.now();
    history.push(record);
    if (history.length > BridgePerformance.MAX_HISTORY_PER_METHOD) {
      history.shift();
    }
  }

  static getTotalCalls(): number {
    return BridgePerformance.totalCalls;
  }

  static getTotalSuccess(): number {
    return BridgePerformance.totalSuccess;
  }

  static getMethodStatsMap(): Map<string, MethodStats> {
    return new Map(BridgePerformance.methodStatsMap);
  }

  static getCallHistory(): Map<string, CallRecord[]> {
    const result = new Map<string, CallRecord[]>();
    BridgePerformance.callHistory.forEach((v, k) => result.set(k, v.slice(0)));
    return result;
  }

  static resetAll(): void {
    BridgePerformance.callHistory.clear();
    BridgePerformance.methodStatsMap.clear();
    BridgePerformance.totalCalls = 0;
    BridgePerformance.totalSuccess = 0;
    BridgePerformance.startTime = Date.now();
  }
}

class CallRecordImpl implements CallRecord {
  method: string = '';
  durationMs: number = 0;
  success: boolean = false;
  timestamp: number = 0;
}

class MethodStatsImpl implements MethodStats {
  method: string = '';
  callCount: number = 0;
  successCount: number = 0;
  failCount: number = 0;
  totalDuration: number = 0;
  minDuration: number = 0;
  maxDuration: number = 0;
  avgDuration: number = 0;
  successRate: number = 0;
}
