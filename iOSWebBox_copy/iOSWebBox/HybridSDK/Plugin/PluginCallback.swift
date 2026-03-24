import Foundation

/// 插件回调接口
public protocol PluginCallback: AnyObject {
    /// 成功回调
    func success(_ data: Any?)

    /// 进度回调
    func progress(_ progress: Int)

    /// 失败回调
    func error(code: String, message: String)

    /// 取消回调
    func cancel()
}

/// PluginCallback实现
public class PluginCallbackImpl: PluginCallback {
    private weak var jsBridge: JSBridge?
    private let callbackId: String

    public init(jsBridge: JSBridge, callbackId: String) {
        self.jsBridge = jsBridge
        self.callbackId = callbackId
    }

    public func success(_ data: Any?) {
        jsBridge?.callJs(
            callbackId: callbackId,
            success: true,
            data: data,
            progress: nil,
            error: nil
        )
    }

    public func progress(_ progress: Int) {
        jsBridge?.callJs(
            callbackId: callbackId,
            success: nil,
            data: nil,
            progress: progress,
            error: nil
        )
    }

    public func error(code: String, message: String) {
        jsBridge?.callJs(
            callbackId: callbackId,
            success: false,
            data: nil,
            progress: nil,
            error: (code, message)
        )
    }

    public func cancel() {
        error(code: "CANCELLED", message: "Operation cancelled by user")
    }
}
