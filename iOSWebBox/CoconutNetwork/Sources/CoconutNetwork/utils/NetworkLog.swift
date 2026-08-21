import Foundation

/// CoconutNetwork 日志出口。
/// 命名避开 CoconutSDK 的 `Logger`（SDK 消费引擎时两者并存）。
/// 宿主 App 可把 sink 接到系统日志（os.Logger / print）。
public enum NetworkLog {

    /// 可替换的日志出口（level: d/i/w/e）
    public nonisolated(unsafe) static var sink: @Sendable (String, String, String) -> Void =
        { level, tag, message in
            print("[\(level)][\(tag)] \(message)")
        }

    public static func d(_ tag: String, _ message: String) { sink("d", tag, message) }
    public static func i(_ tag: String, _ message: String) { sink("i", tag, message) }
    public static func w(_ tag: String, _ message: String) { sink("w", tag, message) }
    public static func e(_ tag: String, _ message: String) { sink("e", tag, message) }

    /// 静默（测试用）
    public static func silence() {
        sink = { _, _, _ in }
    }
}
