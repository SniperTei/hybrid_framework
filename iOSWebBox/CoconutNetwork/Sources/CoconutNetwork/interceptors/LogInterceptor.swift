import Foundation

/// 日志拦截器 — 记录请求和响应信息，敏感字段脱敏。
public final class LogInterceptor: RequestInterceptor, @unchecked Sendable {

    private let sensitiveHeaders: Set<String>
    private let sensitiveParams: Set<String>

    public init(config: HttpConfig? = nil) {
        let headers = config?.sensitiveHeaders ?? ["Authorization", "Cookie"]
        let params = config?.sensitiveParams ?? ["password", "token", "secret"]
        self.sensitiveHeaders = Set(headers.flatMap { [$0.lowercased(), $0] })
        self.sensitiveParams = Set(params.flatMap { [$0.lowercased(), $0] })
    }

    public func onRequest(_ request: HttpRequest) async -> HttpRequest {
        let maskedHeaders = Self.maskHeaders(request.headers, sensitive: sensitiveHeaders)
        let maskedParams = Self.maskParams(request.params, sensitive: sensitiveParams)
        let bodyStr = request.body.map { Self.maskBody($0, sensitive: sensitiveParams) } ?? "null"

        NetworkLog.i("HttpClient", "--> \(request.method.rawValue) \(request.url)")
        NetworkLog.i("HttpClient", "    Headers: \(maskedHeaders)")
        NetworkLog.i("HttpClient", "    Params: \(maskedParams)")
        NetworkLog.i("HttpClient", "    Body: \(bodyStr)")

        return request
    }

    public func onResponse(_ response: HttpResponse) async -> HttpResponse {
        NetworkLog.i("HttpClient", "<-- HTTP \(response.httpStatus) code=\(response.code) cost=\(response.costTime)ms")
        NetworkLog.i("HttpClient", "    Msg: \(response.msg)")
        return response
    }

    /// 脱敏 Header
    private static func maskHeaders(_ headers: [String: String], sensitive: Set<String>) -> String {
        var result: [String: String] = [:]
        for (key, value) in headers {
            result[key] = sensitive.contains(key) ? "***" : value
        }
        return "\(result)"
    }

    /// 脱敏查询参数
    private static func maskParams(_ params: [String: String], sensitive: Set<String>) -> String {
        var result: [String: String] = [:]
        for (key, value) in params {
            result[key] = sensitive.contains(key) ? "***" : value
        }
        return "\(result)"
    }

    /// 脱敏请求体
    private static func maskBody(_ body: JSONValue, sensitive: Set<String>) -> String {
        guard case .object(let object) = body else {
            return body.serializedString() ?? "\(body)"
        }
        var result: [String: JSONValue] = [:]
        for (key, value) in object {
            result[key] = sensitive.contains(key) ? .string("***") : value
        }
        return JSONValue.object(result).serializedString() ?? "\(body)"
    }
}
