//
//  BasePlugin.swift
//  iOSWebBox
//
//  Base plugin class
//

import Foundation

open class BasePlugin: HybridPlugin {
    public weak var pluginContext: PluginContext?

    public init() {}

    public func pluginName() -> String {
        String(describing: type(of: self)).replacingOccurrences(of: "Plugin", with: "").lowercased()
    }

    public func exec(action: String, params: [String: Any], callback: PluginCallback) {
        callback.error("UNKNOWN_ACTION", message: "Unknown action: \(action)")
    }

    // Helper methods for safe parameter extraction
    public func optString(_ params: [String: Any], _ key: String) -> String? {
        params[key] as? String
    }

    public func optInt(_ params: [String: Any], _ key: String) -> Int? {
        params[key] as? Int
    }

    public func optBool(_ params: [String: Any], _ key: String) -> Bool? {
        params[key] as? Bool
    }

    public func string(_ params: [String: Any], _ key: String, default: String = "") -> String {
        optString(params, key) ?? `default`
    }
}
