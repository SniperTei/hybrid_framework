import Foundation

/// 传输层接口 — 不依赖任何网络 SDK。
/// 换底层（系统栈 / 第三方 / 测试 Fake）只需新增一个 Adapter 实现。
///
/// Adapter 契约：AdapterResponse.body 必须是已解析的 JSONValue
/// （JSON 响应解析成对象/基元；非 JSON 响应包装为 string 基元）。

/// 文件上传表单项
public struct FormDataItem: Sendable {
    public let name: String
    public let contentType: String
    public let remoteFileName: String?
    public let data: Data

    public init(name: String, contentType: String, remoteFileName: String? = nil, data: Data) {
        self.name = name
        self.contentType = contentType
        self.remoteFileName = remoteFileName
        self.data = data
    }
}

/// 响应模式：JSON（默认，body 解析为 JSONValue）或 BYTES（rawBody 携带原始字节）
public enum HttpResponseType: Sendable {
    case json
    case bytes
}

/// Adapter 层的请求对象
public struct AdapterRequest: Sendable {
    public let method: String
    public let url: String
    public let headers: [String: String]
    public let body: JSONValue?
    public let contentType: String
    public let connectTimeout: Int
    public let readTimeout: Int
    public let multiFormDataList: [FormDataItem]
    public let responseType: HttpResponseType

    public init(method: String, url: String, headers: [String: String],
                body: JSONValue?, contentType: String, connectTimeout: Int, readTimeout: Int,
                multiFormDataList: [FormDataItem] = [], responseType: HttpResponseType = .json) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
        self.contentType = contentType
        self.connectTimeout = connectTimeout
        self.readTimeout = readTimeout
        self.multiFormDataList = multiFormDataList
        self.responseType = responseType
    }
}

/// Adapter 层的响应对象（BYTES 模式下 body=nil、rawBody 携带原始字节）
public struct AdapterResponse: Sendable {
    public let httpStatus: Int
    public let headers: [String: String]
    public let body: JSONValue?
    public let rawBody: Data?

    public init(httpStatus: Int, headers: [String: String], body: JSONValue?, rawBody: Data? = nil) {
        self.httpStatus = httpStatus
        self.headers = headers
        self.body = body
        self.rawBody = rawBody
    }
}

/// 传输层接口
public protocol IHttpAdapter: Sendable {
    func send(_ request: AdapterRequest) async throws -> AdapterResponse
}
