import Foundation

/// 出站 URL 守卫结果
public struct UrlGuardResult: Sendable {
    public let allowed: Bool
    public let reason: String

    init(allowed: Bool = false, reason: String = "") {
        self.allowed = allowed
        self.reason = reason
    }
}

/// 出站 URL 守卫（SSRF 防护）
///
/// 规则：
/// - scheme 必须是 http / https（coconut:// / file:// / resource:// / javascript: / 无 scheme 一律拒绝）
/// - allowedDomains 为空 = 放行所有 host
/// - allowedDomains 非空 = host 需精确命中某域名或为其子域名：
///     host == d || host.hasSuffix("." + d)
///   注意后缀匹配带 '.' 分隔，"api.foo.com.evil.com" 不会命中 "foo.com"
public enum UrlGuard {

    private static let allowedSchemes = ["http", "https"]

    /// 校验出站 URL
    /// - Parameters:
    ///   - url: 完整 URL（含 baseUrl 拼接后的）
    ///   - allowedDomains: 域名白名单（空 = 放行所有）
    public static func validate(_ url: String, allowedDomains: [String]) -> UrlGuardResult {
        guard let schemeRange = url.range(of: "://") else {
            return UrlGuardResult(reason: "missing or invalid scheme (http/https only): '\(url)'")
        }

        let scheme = String(url[url.startIndex..<schemeRange.lowerBound]).lowercased()
        guard allowedSchemes.contains(scheme) else {
            return UrlGuardResult(reason: "scheme '\(scheme)' is not allowed (http/https only)")
        }

        let host = extractHost(url, from: schemeRange.upperBound)
        if host.isEmpty {
            return UrlGuardResult(reason: "empty host")
        }

        if allowedDomains.isEmpty {
            return UrlGuardResult(allowed: true, reason: "")
        }

        for domain in allowedDomains {
            let d = domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if d.isEmpty { continue }
            if host == d || host.hasSuffix(".\(d)") {
                return UrlGuardResult(allowed: true, reason: "")
            }
        }

        return UrlGuardResult(reason: "host '\(host)' is not in allowedDomains")
    }

    /// 从 '://' 之后提取 host（到第一个 '/', '?', '#', ':' 为止）
    private static func extractHost(_ url: String, from hostStart: String.Index) -> String {
        var end = url.endIndex
        for ch in ["/", "?", "#", ":"] {
            if let idx = url.range(of: ch, range: hostStart..<url.endIndex)?.lowerBound,
               idx < end {
                end = idx
            }
        }
        return String(url[hostStart..<end]).lowercased()
    }
}
