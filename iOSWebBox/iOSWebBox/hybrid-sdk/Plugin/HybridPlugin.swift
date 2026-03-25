//
//  HybridPlugin.swift
//  iOSWebBox
//
//  Plugin protocol definition
//

import Foundation

public protocol HybridPlugin: AnyObject {
    var pluginContext: PluginContext? { get set }

    func pluginName() -> String

    func exec(action: String, params: [String: Any], callback: PluginCallback)

    func onAttach(context: PluginContext)
    func onDetach()
}

public extension HybridPlugin {
    func onAttach(context: PluginContext) {
        // Default implementation
    }

    func onDetach() {
        // Default implementation
    }
}
