import Foundation
import UIKit

open class BaseComponent: CoconutPlugin {

    public init() {}

    open var name: String { "" }
    open var version: String { "1.0.0" }
    open var pluginDescription: String { "" }
    open var dependencies: [String] { [] }

    private var _initialized = false
    public var isInitialized: Bool { _initialized }

    open func onInit(context: ComponentContext) async {}
    open func handle(function: String, params: [String: Any]?) async throws -> [String: Any] {
        try functionNotSupportedError(function)
    }
    open func onCleanup() async {}

    public final func initComponent(context: ComponentContext) async throws {
        guard !_initialized else {
            Logger.shared.w(name, "Component already initialized")
            return
        }
        Logger.shared.d(name, "Initializing component...")
        await onInit(context: context)
        _initialized = true
        Logger.shared.i(name, "✓ Component initialized")
    }

    public final func cleanup() async {
        Logger.shared.d(name, "Cleaning up component...")
        await onCleanup()
        _initialized = false
        Logger.shared.d(name, "✓ Component cleaned up")
    }

    // MARK: - Helper Methods

    public func getParam(_ params: [String: Any]?, _ key: String, _ defaultValue: String = "") -> String {
        guard let value = params?[key] else { return defaultValue }
        if let str = value as? String { return str }
        return "\(value)"
    }

    public func getIntParam(_ params: [String: Any]?, _ key: String, _ defaultValue: Int = 0) -> Int {
        guard let value = params?[key] else { return defaultValue }
        if let int = value as? Int { return int }
        if let str = value as? String, let int = Int(str) { return int }
        if let double = value as? Double { return Int(double) }
        return defaultValue
    }

    public func getLongParam(_ params: [String: Any]?, _ key: String, _ defaultValue: Int64 = 0) -> Int64 {
        guard let value = params?[key] else { return defaultValue }
        if let int = value as? Int64 { return int }
        if let int = value as? Int { return Int64(int) }
        if let str = value as? String, let int = Int64(str) { return int }
        if let double = value as? Double { return Int64(double) }
        return defaultValue
    }

    public func getBoolParam(_ params: [String: Any]?, _ key: String, _ defaultValue: Bool = false) -> Bool {
        guard let value = params?[key] else { return defaultValue }
        if let bool = value as? Bool { return bool }
        if let str = value as? String { return str.lowercased() == "true" }
        return defaultValue
    }

    /// Build success result - returns data dict directly.
    /// Bridge layer handles code/message at top level.
    public func success(_ data: [String: Any]? = nil) -> [String: Any] {
        return data ?? [:]
    }

    /// Throw component error to be caught by Bridge layer
    public func error(_ code: String, _ message: String) throws -> Never {
        throw ComponentException(code: code, message: message)
    }

    /// Throw function not supported error
    public func functionNotSupportedError(_ function: String) throws -> Never {
        throw ComponentException(code: ErrorCode.UNKNOWN_FUNCTION, message: "Function not supported: \(function)")
    }
}
