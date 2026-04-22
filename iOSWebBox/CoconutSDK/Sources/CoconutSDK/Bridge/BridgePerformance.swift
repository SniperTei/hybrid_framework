import Foundation

public class BridgePerformance {

    public static let shared = BridgePerformance()

    public struct CallRecord {
        public let method: String
        public let durationMs: Int64
        public let success: Bool
        public let timestamp: Int64
    }

    public struct MethodStats {
        public var callCount: Int = 0
        public var successCount: Int = 0
        public var failCount: Int = 0
        public var totalDuration: Int64 = 0
        public var minDuration: Int64 = Int64.max
        public var maxDuration: Int64 = 0

        public var avgDuration: Int64 {
            callCount > 0 ? totalDuration / Int64(callCount) : 0
        }
        public var successRate: Double {
            callCount > 0 ? Double(successCount) / Double(callCount) : 0
        }

        public func toDict() -> [String: Any] {
            return [
                "callCount": callCount,
                "successCount": successCount,
                "failCount": failCount,
                "totalDuration": totalDuration,
                "minDuration": minDuration == Int64.max ? 0 : minDuration,
                "maxDuration": maxDuration,
                "avgDuration": avgDuration,
                "successRate": successRate
            ]
        }
    }

    private var callHistory: [CallRecord] = []
    private var methodStatsMap: [String: MethodStats] = [:]
    private let lock = NSLock()

    private init() {}

    public func record(method: String, durationMs: Int64, success: Bool) {
        lock.lock()
        defer { lock.unlock() }

        let record = CallRecord(
            method: method,
            durationMs: durationMs,
            success: success,
            timestamp: Int64(Date().timeIntervalSince1970 * 1000)
        )
        callHistory.append(record)

        var stats = methodStatsMap[method] ?? MethodStats()
        stats.callCount += 1
        if success { stats.successCount += 1 } else { stats.failCount += 1 }
        stats.totalDuration += durationMs
        stats.minDuration = min(stats.minDuration, durationMs)
        stats.maxDuration = max(stats.maxDuration, durationMs)
        methodStatsMap[method] = stats
    }

    public func getTotalCalls() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return callHistory.count
    }

    public func getTotalSuccess() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return callHistory.filter { $0.success }.count
    }

    public func getMethodStatsMap() -> [String: MethodStats] {
        lock.lock()
        defer { lock.unlock() }
        return methodStatsMap
    }

    public func getCallHistory(limit: Int = 100) -> [CallRecord] {
        lock.lock()
        defer { lock.unlock() }
        return Array(callHistory.suffix(limit))
    }

    public func resetAll() {
        lock.lock()
        defer { lock.unlock() }
        callHistory.removeAll()
        methodStatsMap.removeAll()
    }
}
