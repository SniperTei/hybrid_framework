import Foundation

/// HTTP 客户端 — Call 的工厂。持有全局配置、适配器、拦截器。
///
///     let client = HttpClient(HttpConfig())
///     let resp = await client.get("https://api.example.com/users/1")
public final class HttpClient: @unchecked Sendable {

    /// 全局配置（引用语义，可在运行期调整，如同步 allowedDomains）
    public let config: HttpConfig

    private let adapter: IHttpAdapter
    private let lock = NSLock()
    private var _interceptors: [RequestInterceptor] = []

    public init(_ config: HttpConfig = HttpConfig(), adapter: IHttpAdapter? = nil) {
        self.config = config
        self.adapter = adapter ?? URLSessionAdapter()
    }

    /// 创建请求（应用 options；值语义，链式方法返回副本）
    public func newRequest(_ url: String, _ options: RequestOptions? = nil) -> HttpRequest {
        HttpRequest(url: url, options: options)
    }

    // ---- 一发式便利 API（native-first：主要消费者是 native，如热更新下载）----
    // 内部统一走完整管线：拦截器 / UrlGuard / 重试 / header 合并 / mock 短路全部自动生效

    /// 一发式请求（method 等由 options 指定）
    public func request(_ url: String, options: RequestOptions? = nil) async -> HttpResponse {
        await execute(newRequest(url, options))
    }

    public func get(_ url: String, options: RequestOptions? = nil) async -> HttpResponse {
        var opts = options ?? RequestOptions()
        opts.method = .get
        return await request(url, options: opts)
    }

    /// body 显式传入时优先于 options.body
    public func post(_ url: String, body: JSONValue? = nil, options: RequestOptions? = nil) async -> HttpResponse {
        var opts = options ?? RequestOptions()
        opts.method = .post
        if let body { opts.body = body }
        return await request(url, options: opts)
    }

    public func put(_ url: String, body: JSONValue? = nil, options: RequestOptions? = nil) async -> HttpResponse {
        var opts = options ?? RequestOptions()
        opts.method = .put
        if let body { opts.body = body }
        return await request(url, options: opts)
    }

    public func delete(_ url: String, options: RequestOptions? = nil) async -> HttpResponse {
        var opts = options ?? RequestOptions()
        opts.method = .delete
        return await request(url, options: opts)
    }

    /// 添加拦截器
    public func addInterceptor(_ interceptor: RequestInterceptor) {
        lock.lock()
        _interceptors.append(interceptor)
        lock.unlock()
    }

    /// 当前拦截器快照
    public var interceptors: [RequestInterceptor] {
        lock.lock()
        defer { lock.unlock() }
        return _interceptors
    }

    /// 执行请求（完整管线）
    public func execute(_ request: HttpRequest) async -> HttpResponse {
        let call = Call(request: request, config: config, adapter: adapter, interceptors: interceptors)
        return await call.execute()
    }
}
