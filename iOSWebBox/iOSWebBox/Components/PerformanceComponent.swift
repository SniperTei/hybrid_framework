import Foundation
import CoconutSDK

public class PerformanceComponent: BaseComponent {
    public init() { super.init() }

    override public var name: String { "performance" }
    override public var version: String { "1.0.0" }
    override public var pluginDescription: String { "Bridge performance metrics component" }

    override public func handle(function: String, params: [String: Any]?) async throws -> [String: Any] {
        switch function {
        case "getMetrics": return getMetrics()
        case "getMethodStats": return getMethodStats(params)
        case "getSlowCalls": return getSlowCalls(params)
        case "reset": return reset()
        default: try functionNotSupportedError(function)
        }
    }

    private func getMetrics() -> [String: Any] {
        let perf = BridgePerformance.shared
        return success([
            "totalCalls": perf.getTotalCalls(),
            "totalSuccess": perf.getTotalSuccess(),
            "totalFail": perf.getTotalCalls() - perf.getTotalSuccess()
        ])
    }

    private func getMethodStats(_ params: [String: Any]?) -> [String: Any] {
        let method = getParam(params, "method")
        let statsMap = BridgePerformance.shared.getMethodStatsMap()

        if !method.isEmpty {
            guard let stats = statsMap[method] else {
                return success(["method": method, "found": false])
            }
            return success([
                "method": method,
                "found": true,
                "stats": stats.toDict()
            ])
        }

        let allStats = statsMap.map { (method, stats) -> [String: Any] in
            return ["method": method, "stats": stats.toDict()]
        }
        return success(["methods": allStats])
    }

    private func getSlowCalls(_ params: [String: Any]?) -> [String: Any] {
        let threshold = getInt64Param(params, "thresholdMs", 500)
        let history = BridgePerformance.shared.getCallHistory(limit: 1000)
        let slowCalls = history.filter { $0.durationMs > threshold }.map { record -> [String: Any] in
            return [
                "method": record.method,
                "durationMs": record.durationMs,
                "success": record.success,
                "timestamp": record.timestamp
            ]
        }
        return success(["thresholdMs": threshold, "count": slowCalls.count, "calls": slowCalls])
    }

    private func reset() -> [String: Any] {
        BridgePerformance.shared.resetAll()
        return success(["reset": true])
    }

    private func getInt64Param(_ params: [String: Any]?, _ key: String, _ defaultValue: Int64) -> Int64 {
        guard let value = params?[key] else { return defaultValue }
        if let i = value as? Int { return Int64(i) }
        if let d = value as? Double { return Int64(d) }
        if let s = value as? String, let i = Int64(s) { return i }
        return defaultValue
    }
}
