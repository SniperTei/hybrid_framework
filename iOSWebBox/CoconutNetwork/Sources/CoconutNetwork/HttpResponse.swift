import Foundation

/// API 成功码（业务 envelope 约定，与桥接层 API_SUCCESS_CODE 一致）
public let API_SUCCESS_CODE = "000000"

/// HTTP 完整响应 = 业务 envelope + HTTP 传输层信息。
/// 对齐服务端统一响应格式：
/// `{ code: "000000", statusCode: 200, msg: "...", data: {...}, timestamp: "..." }`
public struct HttpResponse: Sendable {

    /// 业务码（字符串，如 "000000"）
    public var code: String = ""

    /// 服务端返回的状态码
    public var statusCode: Int = 200

    /// 消息
    public var msg: String = ""

    /// 业务数据
    public var data: JSONValue?

    /// 服务端时间戳
    public var timestamp: String = ""

    /// HTTP 状态码（传输层）
    public var httpStatus: Int = 200

    /// 响应头
    public var headers: [String: String] = [:]

    /// 原始响应字节（BYTES 模式直通，不做 envelope 嗅探；JSON 模式恒为 nil）
    public var rawData: Data?

    /// 请求耗时（毫秒）
    public var costTime: Int64 = 0

    /// 是否业务成功
    public func isSuccess() -> Bool { code == API_SUCCESS_CODE }

    public static func success(httpStatus: Int, data: JSONValue?, msg: String = "success") -> HttpResponse {
        var resp = HttpResponse()
        resp.code = API_SUCCESS_CODE
        resp.httpStatus = httpStatus
        resp.statusCode = httpStatus
        resp.data = data
        resp.msg = msg
        return resp
    }

    public static func error(code: String, httpStatus: Int, msg: String) -> HttpResponse {
        var resp = HttpResponse()
        resp.code = code
        resp.httpStatus = httpStatus
        resp.msg = msg
        return resp
    }
}
