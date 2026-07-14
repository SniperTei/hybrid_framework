import Foundation
import CoconutSDK

public class StorageComponent: BaseComponent {
    override public init() { super.init() }

    override public var name: String { "storage" }
    override public var version: String { "1.0.0" }
    override public var pluginDescription: String { "Persistent storage component" }

    private var defaults: UserDefaults? {
        return UserDefaults(suiteName: "CoconutStorage")
    }

    override public func handle(function: String, params: [String: Any]?) async throws -> [String: Any] {
        switch function {
        case "setItem": return try setItem(params)
        case "getItem": return try getItem(params)
        case "removeItem": return try removeItem(params)
        case "clear": return clear()
        case "getAllKeys": return getAllKeys()
        case "getSize": return getSize()
        default: try functionNotSupportedError(function)
        }
    }

    private func setItem(_ params: [String: Any]?) throws -> [String: Any] {
        let key = getParam(params, "key")
        let value = getParam(params, "value")
        if key.isEmpty { try error("200007", "Key cannot be empty") }
        defaults?.set(value, forKey: key)
        return success(["success": true])
    }

    private func getItem(_ params: [String: Any]?) throws -> [String: Any] {
        let key = getParam(params, "key")
        if key.isEmpty { try error("200007", "Key cannot be empty") }
        let value = defaults?.string(forKey: key)
        return success(["value": value ?? "", "exists": value != nil])
    }

    private func removeItem(_ params: [String: Any]?) throws -> [String: Any] {
        let key = getParam(params, "key")
        if key.isEmpty { try error("200007", "Key cannot be empty") }
        defaults?.removeObject(forKey: key)
        return success(["success": true])
    }

    private func clear() -> [String: Any] {
        if let defaults = defaults {
            for key in defaults.dictionaryRepresentation().keys {
                defaults.removeObject(forKey: key)
            }
        }
        return success(["success": true])
    }

    private func getAllKeys() -> [String: Any] {
        let keys = defaults?.dictionaryRepresentation().keys.map { $0 } ?? []
        return success(["keys": keys, "count": keys.count])
    }

    private func getSize() -> [String: Any] {
        let count = defaults?.dictionaryRepresentation().count ?? 0
        return success(["count": count, "size": count * 100])
    }
}
