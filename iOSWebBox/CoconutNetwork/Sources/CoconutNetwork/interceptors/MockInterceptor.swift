import Foundation

/// Mock 载体：命中规则后挂到 request.mockResponse，由 Call 短路消费。
public enum MockPayload: Sendable {
    case result(MockResult)
    case data(JSONValue)
}

/// Mock 结果（带状态码/业务码/延时的完整形态）
public struct MockResult: Sendable {
    public var httpStatus: Int = 200
    public var code: String = API_SUCCESS_CODE
    public var msg: String = "mock"
    public var data: JSONValue?
    public var delayMs: Int64 = 0

    public init(httpStatus: Int = 200, code: String = API_SUCCESS_CODE,
                msg: String = "mock", data: JSONValue? = nil, delayMs: Int64 = 0) {
        self.httpStatus = httpStatus
        self.code = code
        self.msg = msg
        self.data = data
        self.delayMs = delayMs
    }
}

/// Mock 规则 — url 精确匹配；以 '*' 结尾 = 前缀匹配（显式声明，避免误命中）。
public struct MockRule: Sendable {
    /// 匹配的 URL（相对或绝对均可，与 request.url 按字符串比对）；以 '*' 结尾 = 前缀匹配
    public let url: String
    /// 匹配的 HTTP 方法；nil = 任意方法
    public let method: HttpMethod?
    /// mock 的 HTTP 状态码，默认 200
    public let httpStatus: Int?
    /// mock 的业务码，默认 "000000"
    public let code: String?
    /// mock 的消息
    public let msg: String?
    /// mock 的数据
    public let data: JSONValue?
    /// 模拟耗时（毫秒），用于测试慢网络
    public let delayMs: Int64?

    public init(url: String, method: HttpMethod? = nil, httpStatus: Int? = nil,
                code: String? = nil, msg: String? = nil, data: JSONValue? = nil,
                delayMs: Int64? = nil) {
        self.url = url
        self.method = method
        self.httpStatus = httpStatus
        self.code = code
        self.msg = msg
        self.data = data
        self.delayMs = delayMs
    }
}

/// Mock 拦截器 — 开发调试用：命中规则时给 request 打 mock 标记，
/// Call.execute 看到标记直接短路，不进 adapter。
///
/// 用法：
///     let mock = MockInterceptor()
///     mock.addRule(MockRule(url: "/api/user", method: .get, data: .object(["name": .string("test")])))
///     mock.addRule(MockRule(url: "/api/login*", httpStatus: 500, code: "500000", msg: "mock fail"))
///     client.addInterceptor(mock)
///
/// 注意：mock 短路发生在 UrlGuard 之前（mock 请求不出网），且生产包不建议注册。
public final class MockInterceptor: RequestInterceptor, @unchecked Sendable {

    private let lock = NSLock()
    private var _rules: [MockRule] = []

    public init() {}

    /// 注册 Mock 规则（链式）
    @discardableResult
    public func addRule(_ rule: MockRule) -> MockInterceptor {
        lock.lock()
        _rules.append(rule)
        lock.unlock()
        return self
    }

    /// 清除所有 Mock 规则
    public func clearAll() {
        lock.lock()
        _rules.removeAll()
        lock.unlock()
    }

    public func onRequest(_ request: HttpRequest) async -> HttpRequest {
        guard let rule = match(request) else { return request }
        NetworkLog.i("MockInterceptor", "Mock hit: \(rule.method?.rawValue ?? "*") \(rule.url)")
        var mocked = request
        mocked.enableMock = true
        mocked.mockResponse = .result(MockResult(
            httpStatus: rule.httpStatus ?? 200,
            code: rule.code ?? API_SUCCESS_CODE,
            msg: rule.msg ?? "mock",
            data: rule.data,
            delayMs: rule.delayMs ?? 0
        ))
        return mocked
    }

    public func onResponse(_ response: HttpResponse) async -> HttpResponse { response }

    /// 匹配规则：URL 精确 / '*' 前缀 + 方法校验（nil = 任意）
    private func match(_ request: HttpRequest) -> MockRule? {
        lock.lock()
        let rules = _rules
        lock.unlock()
        let methodStr = request.method.rawValue.uppercased()
        for rule in rules {
            if let method = rule.method, method.rawValue.uppercased() != methodStr {
                continue
            }
            let pattern = rule.url
            if pattern.hasSuffix("*") {
                if request.url.hasPrefix(String(pattern.dropLast())) {
                    return rule
                }
            } else if request.url == pattern {
                return rule
            }
        }
        return nil
    }
}
