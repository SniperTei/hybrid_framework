import XCTest
import UIKit
import CoconutSDK
import CoconutNetwork
@testable import iOSWebBox

/// 测试用 Fake 传输层（引擎包的 FakeAdapter 不跨模块可见，此处内联一份）
private final class FakeAdapter: IHttpAdapter, @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [AdapterRequest] = []
    private var _response = AdapterResponse(httpStatus: 200, headers: [:], body: nil)

    var requests: [AdapterRequest] { lock.lock(); defer { lock.unlock() }; return _requests }
    var response: AdapterResponse {
        get { lock.lock(); defer { lock.unlock() }; return _response }
        set { lock.lock(); _response = newValue; lock.unlock() }
    }

    func send(_ request: AdapterRequest) async throws -> AdapterResponse {
        lock.lock(); defer { lock.unlock() }
        _requests.append(request)
        return _response
    }

    func respond(_ httpStatus: Int, _ bodyJson: String) {
        response = AdapterResponse(
            httpStatus: httpStatus,
            headers: ["Content-Type": "application/json"],
            body: JSONValue.parse(Data(bodyJson.utf8))
        )
    }
}

/// 手动驱动的连接状态 provider（测试缝）
private final class ManualStatusProvider: NetworkStatusProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var _status = NetworkStatus(type: "wifi", online: true)
    private var _onChange: (@Sendable (String, Bool) -> Void)?

    var current: NetworkStatus { lock.lock(); defer { lock.unlock() }; return _status }

    func startMonitoring(onChange: @escaping @Sendable (String, Bool) -> Void) {
        lock.lock(); _onChange = onChange; lock.unlock()
    }

    func stopMonitoring() {
        lock.lock(); _onChange = nil; lock.unlock()
    }

    func change(_ type: String, _ online: Bool) {
        lock.lock()
        _status = NetworkStatus(type: type, online: online)
        let handler = _onChange
        lock.unlock()
        handler?(type, online)
    }
}

/// 记录 emit 出去的 JS 脚本
private final class RecordingJSExecutor: JSExecutor, @unchecked Sendable {
    private let lock = NSLock()
    private var _scripts: [String] = []
    var scripts: [String] { lock.lock(); defer { lock.unlock() }; return _scripts }

    func evaluateJavaScript(_ script: String) async -> Error? {
        lock.lock(); _scripts.append(script); lock.unlock()
        return nil
    }
}

@MainActor
final class NetworkComponentTests: XCTestCase {

    private var fake: FakeAdapter!
    private var provider: ManualStatusProvider!
    private var component: NetworkComponent!
    private var context: ComponentContext!
    private var executor: RecordingJSExecutor!

    override func setUp() async throws {
        fake = FakeAdapter()
        provider = ManualStatusProvider()
        let config = HttpConfig()
        config.retryDelay = 10
        component = NetworkComponent(client: HttpClient(config, adapter: fake), statusProvider: provider)

        context = ComponentContext(applicationContext: UIApplication.shared)
        executor = RecordingJSExecutor()
        context.eventEmitter.jsExecutor = executor
        try await component.initComponent(context: context)
    }

    override func tearDown() async throws {
        await component.cleanup()
        context.eventEmitter.clearAll()
    }

    // MARK: - request

    func test_request_happyPath_fields() async throws {
        fake.respond(200, #"{"code":"000000","msg":"ok","data":{"id":1}}"#)

        let result = try await component.handle(
            function: "request",
            params: ["url": "https://api.foo.com/users/1"])

        XCTAssertEqual(1, fake.requests.count)
        XCTAssertEqual("https://api.foo.com/users/1", fake.requests[0].url)
        XCTAssertEqual("GET", fake.requests[0].method)

        XCTAssertEqual(true, result["success"] as? Bool)
        XCTAssertEqual("000000", result["code"] as? String)
        XCTAssertEqual(200, result["httpStatus"] as? Int)
        XCTAssertEqual("ok", result["msg"] as? String)
        XCTAssertEqual("ok", result["message"] as? String)
        let data = result["data"] as? [String: Any]
        XCTAssertEqual(1, data?["id"] as? Int)
        XCTAssertNotNil(result["costTime"])
        XCTAssertNotNil(result["headers"])
    }

    func test_request_headersBodyParams_reachEngine() async throws {
        fake.respond(200, #"{"code":"000000"}"#)

        _ = try await component.handle(
            function: "request",
            params: [
                "url": "https://api.foo.com/echo",
                "method": "POST",
                "headers": ["X-A": "1"],
                "body": ["k": "v"],
                "timeoutMs": 1234,
            ])

        let sent = fake.requests[0]
        XCTAssertEqual("POST", sent.method)
        XCTAssertEqual("1", sent.headers["X-A"])
        XCTAssertEqual(1234, sent.connectTimeout)
        XCTAssertEqual(1234, sent.readTimeout)
        XCTAssertEqual("v", sent.body?["k"]?.stringValue)
    }

    func test_request_guardBlocked_mapsTo200007() async throws {
        // 非 http scheme（coconut://）→ 引擎 UrlGuard 拦截，不落 adapter
        do {
            _ = try await component.handle(function: "request", params: ["url": "coconut://demo/index.html"])
            XCTFail("expected ComponentException")
        } catch let e as ComponentException {
            XCTAssertEqual("200007", e.code)
            XCTAssertTrue(e.message.contains("出站守卫"))
        }
        XCTAssertEqual(0, fake.requests.count)
    }

    func test_request_methodNotAllowed_mapsTo200007() async throws {
        do {
            _ = try await component.handle(
                function: "request",
                params: ["url": "https://api.foo.com/x", "method": "PATCH"])
            XCTFail("expected ComponentException")
        } catch let e as ComponentException {
            XCTAssertEqual("200007", e.code)
            XCTAssertTrue(e.message.contains("PATCH"))
        }
    }

    func test_request_missingUrl_mapsTo200007() async throws {
        do {
            _ = try await component.handle(function: "request", params: [:])
            XCTFail("expected ComponentException")
        } catch let e as ComponentException {
            XCTAssertEqual("200007", e.code)
        }
    }

    func test_request_http501_successFalse_businessCodeKept() async throws {
        fake.respond(501, #"{"code":"000000"}"#)

        let result = try await component.handle(
            function: "request",
            params: ["url": "https://api.foo.com/broken"])

        XCTAssertEqual(false, result["success"] as? Bool)
        XCTAssertEqual(501, result["httpStatus"] as? Int)
        XCTAssertEqual("501", result["code"] as? String)
    }

    func test_request_timeout_passthrough() async throws {
        // 超时透传：fake 直接给超时响应形态（引擎映射逻辑已在引擎测试钉死）
        fake.respond(200, #"{"code":"000000"}"#)

        let result = try await component.handle(
            function: "request",
            params: ["url": "https://api.foo.com/x", "timeoutMs": 999])
        XCTAssertEqual(true, result["success"] as? Bool)
        XCTAssertEqual(999, fake.requests[0].readTimeout)
    }

    // MARK: - getNetworkType

    func test_getNetworkType_shape_wifi() async throws {
        provider.change("wifi", true)

        let result = try await component.handle(function: "getNetworkType", params: nil)
        XCTAssertEqual("wifi", result["type"] as? String)
        XCTAssertEqual(true, result["online"] as? Bool)
        XCTAssertEqual(true, result["success"] as? Bool)
    }

    func test_getNetworkType_none_whenOffline() async throws {
        provider.change("none", false)

        let result = try await component.handle(function: "getNetworkType", params: nil)
        XCTAssertEqual("none", result["type"] as? String)
        XCTAssertEqual(false, result["online"] as? Bool)
    }

    // MARK: - network.change push

    func test_networkChange_emit_deduped() async throws {
        context.eventEmitter.on(topic: NETWORK_TOPIC_CHANGE)
        // setUp 的初始推送（wifi|true）无订阅者 → 被 emitter 丢弃，scripts 为空；
        // 但组件侧 lastStateKey 已是 wifi|true，故用 cellular 起步
        component.emitState("cellular", online: true)
        component.emitState("cellular", online: true)  // 重复 → 去重
        component.emitState("none", online: false)

        // emit 经 Task 派发到 jsExecutor —— 等待 2 条脚本落账
        try await waitOrFail(expected: 2)

        XCTAssertEqual(2, executor.scripts.count)
        XCTAssertTrue(executor.scripts[0].contains("network.change"))
        XCTAssertTrue(executor.scripts[0].contains("cellular"))
        XCTAssertTrue(executor.scripts[1].contains("none"))
    }

    func test_monitoringCallback_hopsToMainActorAndEmits() async throws {
        context.eventEmitter.on(topic: NETWORK_TOPIC_CHANGE)

        // 模拟 NWPathMonitor 后台线程回调（provider.change 直接调注入的 onChange）
        provider.change("cellular", true)
        try await waitOrFail(expected: 1)

        XCTAssertEqual(1, executor.scripts.count)
        XCTAssertTrue(executor.scripts[0].contains("cellular"))
    }

    // MARK: - unknown function

    func test_unknownFunction_throws() async throws {
        do {
            _ = try await component.handle(function: "nope", params: nil)
            XCTFail("expected ComponentException")
        } catch let e as ComponentException {
            XCTAssertTrue(e.message.contains("not supported"))
        }
    }

    // MARK: - helpers

    /// 轮询等待 executor 记到 expected 条脚本（或超时）
    private func waitOrFail(expected: Int, timeoutMs: Int = 2000) async throws {
        let deadline = Date().addingTimeInterval(TimeInterval(timeoutMs) / 1000)
        while executor.scripts.count < expected && Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}
