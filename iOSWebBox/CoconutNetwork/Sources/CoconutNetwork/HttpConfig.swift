import Foundation

/// HTTP 全局配置 — 启动时创建一次，传入 HttpClient。
/// 引用语义（class）：NetworkComponent 每次请求同步 `allowedDomains` 时
/// 依赖此身份；纯 Foundation，不依赖任何 SDK。
public final class HttpConfig: @unchecked Sendable {

    /// 服务器基础地址
    public var baseUrl: String = ""

    /// 公共请求头（所有请求都会带上，单次请求同名 header 覆盖）
    public var headers: [String: String] = [:]

    /// 连接超时（毫秒）
    public var connectTimeout: Int = 15000

    /// 读取超时（毫秒）
    public var readTimeout: Int = 30000

    /// 重试次数
    public var retryCount: Int = 2

    /// 重试间隔（毫秒）
    public var retryDelay: Int = 1000

    /// 启用日志
    public var enableLog: Bool = false

    /// 日志中脱敏的 Header 字段
    public var sensitiveHeaders: [String] = ["Authorization", "Cookie"]

    /// 日志中脱敏的参数字段
    public var sensitiveParams: [String] = ["password", "token", "secret"]

    /// 出站域名白名单（SSRF 守卫）
    /// 空 = 放行所有 host；非空 = host 需精确命中或为其子域名
    /// （host == d || host.hasSuffix("." + d)）
    public var allowedDomains: [String] = []

    public init() {}
}
