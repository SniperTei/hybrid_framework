import Foundation
import CoconutSDK
import CoconutNetwork
import Network

/// Topic emitted on network type/online changes (deduped).
public let NETWORK_TOPIC_CHANGE = "network.change"

private let ALLOWED_METHODS = ["GET", "POST", "PUT", "DELETE"]

/// 连接状态快照
public struct NetworkStatus: Sendable {
    public let type: String   // wifi | cellular | ethernet | none | unknown
    public let online: Bool

    public init(type: String, online: Bool) {
        self.type = type
        self.online = online
    }
}

/// 连接状态提供者 — 测试缝（ManualStatusProvider）/ 生产（NWPathStatusProvider）
public protocol NetworkStatusProviding: AnyObject {
    /// 当前状态（同步快照）
    var current: NetworkStatus { get }
    /// 启动监听；onChange 可能在任意线程回调（组件内部自行 hop MainActor）
    func startMonitoring(onChange: @escaping @Sendable (String, Bool) -> Void)
    func stopMonitoring()
}

/// 基于 NWPathMonitor 的生产实现。
/// NWPathMonitor 单流天然合并事件（无 Harmony NetConnection 150ms 合并之需）。
public final class NWPathStatusProvider: NetworkStatusProviding, @unchecked Sendable {

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.sniper.coconut.network.status")
    private let lock = NSLock()
    private var onChange: (@Sendable (String, Bool) -> Void)?
    private var started = false

    public init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            self.lock.lock()
            let handler = self.onChange
            self.lock.unlock()
            let online = path.status == .satisfied
            handler?(online ? Self.map(path) : "none", online)
        }
    }

    public var current: NetworkStatus {
        let path = monitor.currentPath
        let online = path.status == .satisfied
        return NetworkStatus(type: online ? Self.map(path) : "none", online: online)
    }

    public func startMonitoring(onChange: @escaping @Sendable (String, Bool) -> Void) {
        lock.lock()
        self.onChange = onChange
        let shouldStart = !started
        started = true
        lock.unlock()
        if shouldStart {
            monitor.start(queue: queue)
        }
    }

    public func stopMonitoring() {
        lock.lock()
        onChange = nil
        lock.unlock()
    }

    private static func map(_ path: NWPath) -> String {
        if path.usesInterfaceType(.wifi) { return "wifi" }
        if path.usesInterfaceType(.wiredEthernet) { return "ethernet" }
        if path.usesInterfaceType(.cellular) { return "cellular" }
        return "unknown"
    }
}

/**
 * Network Component（第 5 个组件，三端齐活）
 *
 * Bridges the standalone CoconutNetwork engine to the H5 bridge:
 * - request: native HTTP via HttpClient (bypasses WebView CORS, unified
 *   outbound guard). Business-layer failure convention: bridge code 000000
 *   + success:false in the result payload.
 * - getNetworkType: current connectivity (wifi/cellular/ethernet/none/unknown).
 * - network.change: native → H5 push on connectivity change (deduped by
 *   type|online key), reusing the EventEmitter channel.
 *
 * The HttpClient is injectable for tests (FakeAdapter); by default it is
 * created once with allowedDomains re-synced from CoconutSDK config on
 * every request (HttpConfig 引用语义，per-request 同步让之后的
 * CoconutSDK.configure() 域名变更保持生效).
 */
@MainActor
public final class NetworkComponent: BaseComponent {

    /// 默认构造：client 出站白名单与 CoconutSDK 入站白名单保持同步
    override public convenience init() {
        self.init(client: HttpClient(HttpConfig()),
                  statusProvider: NWPathStatusProvider(),
                  usesSdkWhitelist: true)
    }

    /// 测试注入构造：client/provider 自带配置，不触碰 CoconutSDK
    public convenience init(client: HttpClient, statusProvider: NetworkStatusProviding) {
        self.init(client: client, statusProvider: statusProvider, usesSdkWhitelist: false)
    }

    private init(client: HttpClient, statusProvider: NetworkStatusProviding, usesSdkWhitelist: Bool) {
        self.client = client
        self.statusProvider = statusProvider
        self.usesSdkWhitelist = usesSdkWhitelist
        super.init()
    }

    private let client: HttpClient
    private let statusProvider: NetworkStatusProviding
    private let usesSdkWhitelist: Bool

    private var context: ComponentContext?
    private var lastStateKey = ""

    override public var name: String { "network" }
    override public var version: String { "1.0.0" }
    override public var pluginDescription: String { "Network request + connectivity component" }
    override public var methods: [String] { ["request", "getNetworkType"] }

    override public func handle(function: String, params: [String: Any]?) async throws -> [String: Any] {
        switch function {
        case "request": return try await requestHandler(params)
        case "getNetworkType": return getNetworkTypeHandler()
        default: try functionNotSupportedError(function)
        }
    }

    override public func onInit(context: ComponentContext) async {
        self.context = context
        statusProvider.startMonitoring { [weak self] type, online in
            Task { @MainActor [weak self] in
                self?.emitState(type, online: online)
            }
        }
        // 首次推送携带初始状态
        let status = statusProvider.current
        emitState(status.type, online: status.online)
    }

    override public func onCleanup() async {
        statusProvider.stopMonitoring()
        lastStateKey = ""
    }

    // MARK: - request
    // {url, method, headers, body, params, timeoutMs}
    // → {success, httpStatus, code, msg, data, headers, costTime, message}

    private func requestHandler(_ params: [String: Any]?) async throws -> [String: Any] {
        let url = getParam(params, "url")
        if url.isEmpty {
            try error("200007", "url is required")
        }

        let methodStr = getParam(params, "method", "GET").uppercased()
        let method: HttpMethod
        switch methodStr {
        case "GET": method = .get
        case "POST": method = .post
        case "PUT": method = .put
        case "DELETE": method = .delete
        default:
            // deliberate whitelist — PATCH/HEAD etc. deferred to a later round
            try error("200007", "method not allowed: \(methodStr) (allowed: \(ALLOWED_METHODS.joined(separator: "/")))")
        }

        syncOutboundWhitelist()

        let options = RequestOptions(
            method: method,
            headers: stringMapOf(params, "headers"),
            params: stringMapOf(params, "params")
        )

        let timeoutMs = getIntParam(params, "timeoutMs", 0)

        var request = client.newRequest(url, options)
        if let body = params?["body"] {
            // raw JSON passthrough (contentType stays application/json)
            request = request.setBody(JSONValue.from(any: body))
        }
        if timeoutMs > 0 {
            request = request.setTimeout(connectTimeout: timeoutMs, readTimeout: timeoutMs)
        }

        let resp = await client.execute(request)

        // 出站守卫命中 → 映射为桥接安全错误（200007），对齐入站 BridgeSecurityValidator 语义
        if resp.code == "\(HttpErrorCode.urlBlocked.rawValue)" {
            try error("200007", resp.msg)
        }

        return success([
            "success": resp.isSuccess(),
            "httpStatus": resp.httpStatus,
            "code": resp.code,
            "msg": resp.msg,
            "data": resp.data?.anyValue() ?? NSNull(),
            "headers": resp.headers,
            "costTime": resp.costTime,
            "message": resp.msg,
        ])
    }

    // MARK: - getNetworkType
    // → {type: wifi|cellular|ethernet|none|unknown, online, success}

    private func getNetworkTypeHandler() -> [String: Any] {
        let status = statusProvider.current
        return success([
            "type": status.type,
            "online": status.online,
            "success": true,
        ])
    }

    // MARK: - helpers

    /// Extract a string map from a nested params object
    private func stringMapOf(_ params: [String: Any]?, _ key: String) -> [String: String]? {
        guard let obj = params?[key] as? [String: Any] else { return nil }
        var map: [String: String] = [:]
        for (k, v) in obj {
            if let s = v as? String {
                map[k] = s
            } else if JSONSerialization.isValidJSONObject([v]) || v is NSNumber || v is NSNull {
                map[k] = "\(v)"
            }
        }
        return map
    }

    /// Re-sync outbound guard whitelist from CoconutSDK inbound config
    /// (per request — HttpConfig 引用语义让后续 configure() 变更生效)
    private func syncOutboundWhitelist() {
        guard usesSdkWhitelist, CoconutSDK.isInitialized else { return }
        client.config.allowedDomains = CoconutSDK.getConfig().allowedDomains
    }

    /// Emit network.change, deduped on type|online (first emit carries initial state)
    func emitState(_ type: String, online: Bool) {
        let key = "\(type)|\(online)"
        guard key != lastStateKey else { return }
        lastStateKey = key
        context?.eventEmitter.emit(topic: NETWORK_TOPIC_CHANGE, data: [
            "type": type,
            "online": online,
        ])
    }
}
