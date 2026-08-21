import Foundation

/// HTTP 错误码常量 — 负数区间，避免和 HTTP 状态码、业务码冲突。
public enum HttpErrorCode: Int, Sendable {
    /// 网络错误（DNS、连接失败等）
    case networkError = -1001
    /// 超时
    case timeoutError = -1002
    /// SSL 证书错误
    case sslError = -1003
    /// 出站 URL 被守卫拦截（scheme 非法或 host 不在白名单）
    case urlBlocked = -1004
    /// Token 过期
    case tokenExpired = -2001
    /// Token 无效
    case tokenInvalid = -2002
    /// 服务器错误
    case serverError = -3001
}

/// HTTP 错误分类（真值表 helper）
public enum HttpError: Sendable {

    /// 判断是否为网络层错误
    public static func isNetworkError(_ code: Int) -> Bool {
        (-1099 ... -1001).contains(code)
    }

    /// 判断是否为 Token 相关错误
    public static func isTokenError(_ code: Int) -> Bool {
        code == HttpErrorCode.tokenExpired.rawValue || code == HttpErrorCode.tokenInvalid.rawValue
    }

    /// 判断是否可重试
    public static func isRetryable(_ code: Int) -> Bool {
        code == HttpErrorCode.networkError.rawValue || code == HttpErrorCode.timeoutError.rawValue
    }
}
