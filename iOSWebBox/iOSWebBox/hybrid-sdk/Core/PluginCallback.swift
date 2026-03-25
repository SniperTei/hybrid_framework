//
//  PluginCallback.swift
//  iOSWebBox
//
//  Plugin callback interface
//

import Foundation

public protocol PluginCallback: AnyObject {
    func success(_ data: Any?)
    func progress(_ progress: Int)
    func error(_ code: String, message: String)
}

public class PluginCallbackImpl: PluginCallback {
    private let callbackId: String
    private let jsBridge: JSBridge

    public init(callbackId: String, jsBridge: JSBridge) {
        self.callbackId = callbackId
        self.jsBridge = jsBridge
    }

    public func success(_ data: Any?) {
        jsBridge.callJs(callbackId: callbackId, success: true, data: data, progress: nil, error: nil)
    }

    public func progress(_ progress: Int) {
        jsBridge.callJs(callbackId: callbackId, success: nil, data: nil, progress: progress, error: nil)
    }

    public func error(_ code: String, message: String) {
        jsBridge.callJs(callbackId: callbackId, success: false, data: nil, progress: nil, error: (code, message))
    }
}
