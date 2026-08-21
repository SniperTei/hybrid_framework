import Foundation
@testable import CoconutNetwork

/// URLProtocol stub — URLSessionAdapter 集成测试的惯用等价物
/// （对应 Android 侧的 JDK HttpServer 集成测试，无端口、确定性）。
final class MockURLProtocol: URLProtocol {

    private static let lock = NSLock()
    // 锁保护的可变全局状态（Swift 6 模式下需 nonisolated(unsafe) 标注）
    private nonisolated(unsafe) static var _handler: ((URLRequest) throws -> (Int, [String: String], Data))?
    private nonisolated(unsafe) static var _lastRequest: URLRequest?

    /// 最近一次经 stub 的请求（断言 method/headers/body 用）
    static var lastRequest: URLRequest? {
        lock.lock(); defer { lock.unlock() }
        return _lastRequest
    }

    static func reset() {
        lock.lock()
        _handler = nil
        _lastRequest = nil
        lock.unlock()
    }

    /// URLProtocol 里 httpBody 常为 nil、body 走 httpBodyStream —— 两者都读
    static func body(of request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }

    /// 全局 handler：入参 URLRequest，出参 (status, headers, body)。
    /// 抛错即模拟传输层故障（如 URLError(.timedOut)）。
    static func setHandler(_ handler: ((URLRequest) throws -> (Int, [String: String], Data))?) {
        lock.lock()
        _handler = handler
        lock.unlock()
    }

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        let handler = Self._handler
        Self._lastRequest = request
        Self.lock.unlock()
        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        do {
            let (status, headers, data) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status,
                                           httpVersion: "HTTP/1.1", headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
