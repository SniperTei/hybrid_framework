import Foundation

/// HTTP 方法枚举（不依赖任何平台网络 SDK）
public enum HttpMethod: String, Sendable, CaseIterable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

/// 请求选项
public struct RequestOptions: Sendable {
    public var method: HttpMethod?
    public var headers: [String: String]?
    public var params: [String: String]?
    public var body: JSONValue?
    public var tag: String?
    public var connectTimeout: Int?
    public var readTimeout: Int?
    public var multiFormDataList: [FormDataItem]?
    public var responseType: HttpResponseType?

    public init(method: HttpMethod? = nil, headers: [String: String]? = nil,
                params: [String: String]? = nil, body: JSONValue? = nil,
                tag: String? = nil, connectTimeout: Int? = nil, readTimeout: Int? = nil,
                multiFormDataList: [FormDataItem]? = nil, responseType: HttpResponseType? = nil) {
        self.method = method
        self.headers = headers
        self.params = params
        self.body = body
        self.tag = tag
        self.connectTimeout = connectTimeout
        self.readTimeout = readTimeout
        self.multiFormDataList = multiFormDataList
        self.responseType = responseType
    }
}

/// HTTP 请求对象 — 值语义（struct）：拦截器链中每步返回修改后的副本。
/// 链式方法同样返回副本，原值不变。
public struct HttpRequest: Sendable {

    /// 请求路径（相对 baseUrl）或完整 URL
    public var url: String

    /// HTTP 方法
    public var method: HttpMethod = .get

    /// 请求头
    public var headers: [String: String] = [:]

    /// URL 查询参数
    public var params: [String: String] = [:]

    /// 请求体
    public var body: JSONValue?

    /// 内容类型
    public var contentType: String = "application/json"

    /// 请求标签（用于日志和取消）
    public var tag: String = ""

    /// 文件上传表单数据
    public var multiFormDataList: [FormDataItem] = []

    /// 覆盖全局重试次数（-1 = 未设置）
    public var retryCount: Int = -1

    /// 覆盖全局读取超时（-1 = 未设置）
    public var readTimeout: Int = -1

    /// 覆盖全局连接超时（-1 = 未设置）
    public var connectTimeout: Int = -1

    /// 响应模式（JSON 解析 / BYTES 原始字节直通）
    public var responseType: HttpResponseType = .json

    /// 单请求启用 Mock（由 MockInterceptor 打标，或手动 enableMocking）
    public var enableMock: Bool = false

    /// Mock 响应（MockResult 完整形态，或直接给业务数据）
    public var mockResponse: MockPayload?

    public init(url: String, options: RequestOptions? = nil) {
        self.url = url
        guard let options else { return }
        if let method = options.method { self.method = method }
        if let headers = options.headers {
            for (k, v) in headers { self.headers[k] = v }
        }
        if let params = options.params {
            // POST/PUT → params 自动转 body；GET/DELETE → 保留为 URL 查询参数
            if self.method == .post || self.method == .put {
                self.body = .object(params.mapValues { .string($0) })
            } else {
                for (k, v) in params { self.params[k] = v }
            }
        }
        if let body = options.body { self.body = body }
        if let tag = options.tag { self.tag = tag }
        if let connectTimeout = options.connectTimeout { self.connectTimeout = connectTimeout }
        if let readTimeout = options.readTimeout { self.readTimeout = readTimeout }
        if let responseType = options.responseType { self.responseType = responseType }
        if let multiFormDataList = options.multiFormDataList { self.multiFormDataList = multiFormDataList }
    }

    // MARK: - 链式方法（返回修改后的副本，对齐 Kotlin class 链式风格）

    public func setHeader(_ key: String, _ value: String) -> HttpRequest {
        var copy = self
        copy.headers[key] = value
        return copy
    }

    public func setBody(_ body: JSONValue) -> HttpRequest {
        var copy = self
        copy.body = body
        return copy
    }

    public func setTag(_ tag: String) -> HttpRequest {
        var copy = self
        copy.tag = tag
        return copy
    }

    public func setTimeout(connectTimeout: Int, readTimeout: Int) -> HttpRequest {
        var copy = self
        copy.connectTimeout = connectTimeout
        copy.readTimeout = readTimeout
        return copy
    }

    /// 手动启用 mock（直接给业务数据；带状态码/业务码的 mock 请用 MockInterceptor.addRule）
    public func enableMocking(_ payload: MockPayload) -> HttpRequest {
        var copy = self
        copy.enableMock = true
        copy.mockResponse = payload
        return copy
    }
}
