import Foundation
@testable import CoconutNetwork

/// 测试用 Fake 传输层：可脚本化响应 / 前 N 次抛错
final class FakeAdapter: IHttpAdapter, @unchecked Sendable {

    private let lock = NSLock()
    private var _requests: [AdapterRequest] = []
    private var _response: AdapterResponse = AdapterResponse(httpStatus: 200, headers: [:], body: nil)
    private var _sendCount = 0

    /// 前 failFirstCount 次调用抛 failError（模拟瞬时故障测重试）
    var failFirstCount = 0
    var failError: Error?

    /// 收到的所有请求（按顺序）
    var requests: [AdapterRequest] {
        lock.lock(); defer { lock.unlock() }
        return _requests
    }

    /// 成功时返回的响应
    var response: AdapterResponse {
        get {
            lock.lock(); defer { lock.unlock() }
            return _response
        }
        set {
            lock.lock()
            _response = newValue
            lock.unlock()
        }
    }

    /// 总调用次数
    var sendCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _sendCount
    }

    func send(_ request: AdapterRequest) async throws -> AdapterResponse {
        try recordAndRespond(request)
    }

    /// NSLock 不可在 async 上下文直接用 —— 锁范围收敛进同步 helper
    private func recordAndRespond(_ request: AdapterRequest) throws -> AdapterResponse {
        lock.lock()
        defer { lock.unlock() }
        _requests.append(request)
        _sendCount += 1
        if let failError, _sendCount <= failFirstCount {
            throw failError
        }
        return _response
    }

    /// 设置 envelope 形式的成功响应
    func envelopeResponse(_ httpStatus: Int, _ bodyJson: String) {
        response = AdapterResponse(
            httpStatus: httpStatus,
            headers: ["Content-Type": "application/json"],
            body: JSONValue.parse(Data(bodyJson.utf8))
        )
    }

    /// 设置非 envelope 响应（body 直通）
    func rawResponse(_ httpStatus: Int, _ bodyJson: String) {
        response = AdapterResponse(httpStatus: httpStatus, headers: [:],
                                   body: JSONValue.parse(Data(bodyJson.utf8)))
    }

    /// 设置 bytes 模式响应（rawBody 携带原始字节，body=nil）
    func bytesResponse(_ httpStatus: Int, _ data: Data) {
        response = AdapterResponse(httpStatus: httpStatus, headers: [:], body: nil, rawBody: data)
    }
}
