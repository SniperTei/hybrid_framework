import Foundation

/// 请求拦截器接口 — 请求阶段正序执行，响应阶段逆序执行。
public protocol RequestInterceptor: Sendable {
    /// 请求拦截（值语义：返回修改后的副本）
    func onRequest(_ request: HttpRequest) async -> HttpRequest
    /// 响应拦截
    func onResponse(_ response: HttpResponse) async -> HttpResponse
}
