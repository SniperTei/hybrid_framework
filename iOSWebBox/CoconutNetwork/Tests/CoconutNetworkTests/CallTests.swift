import XCTest
@testable import CoconutNetwork

final class SharedLog: @unchecked Sendable {
    private let lock = NSLock()
    private var _entries: [String] = []
    var entries: [String] {
        lock.lock(); defer { lock.unlock() }
        return _entries
    }
    func append(_ entry: String) {
        lock.lock()
        _entries.append(entry)
        lock.unlock()
    }
}

final class RecordingInterceptor: RequestInterceptor, @unchecked Sendable {
    let name: String
    let log: SharedLog

    init(_ name: String, log: SharedLog) {
        self.name = name
        self.log = log
    }

    func onRequest(_ request: HttpRequest) async -> HttpRequest {
        log.append("\(name):req")
        return request
    }

    func onResponse(_ response: HttpResponse) async -> HttpResponse {
        log.append("\(name):resp")
        return response
    }
}

final class CallTests: XCTestCase {

    private var fake: FakeAdapter!
    private var client: HttpClient!

    override func setUp() {
        super.setUp()
        // 静默引擎日志，避免测试输出噪音
        NetworkLog.silence()
        fake = FakeAdapter()
        let config = HttpConfig()
        config.baseUrl = "https://api.test.com" // UrlGuard 要求完整 http/https URL
        config.retryDelay = 10 // 测试重试不等 1s
        client = HttpClient(config, adapter: fake)
    }

    override func tearDown() {
        MockURLProtocol.setHandler(nil)
        super.tearDown()
    }

    func test_envelope200_parsesCodeMsgData() async {
        fake.envelopeResponse(200, #"{"code":"000000","msg":"ok","data":{"id":1},"timestamp":"t1"}"#)
        let resp = await client.execute(client.newRequest("/users/1"))
        XCTAssertTrue(resp.isSuccess())
        XCTAssertEqual(200, resp.httpStatus)
        XCTAssertEqual("ok", resp.msg)
        XCTAssertEqual("t1", resp.timestamp)
        XCTAssertEqual(1, resp.data?["id"]?.intValue)
        // 响应头透传 + 请求 contentType 默认值
        XCTAssertEqual("application/json", resp.headers["Content-Type"])
        XCTAssertEqual("application/json", fake.requests[0].contentType)
    }

    func test_envelopeBusinessFail_codeKept_successFalse() async {
        fake.envelopeResponse(200, #"{"code":"500000","msg":"server busy","data":null}"#)
        let resp = await client.execute(client.newRequest("/x"))
        XCTAssertEqual(200, resp.httpStatus)
        XCTAssertFalse(resp.isSuccess())
        XCTAssertEqual("500000", resp.code)
    }

    func test_http404_returnsHttpError() async {
        fake.envelopeResponse(404, #"{"code":"000000","msg":"not found"}"#)
        let resp = await client.execute(client.newRequest("/missing"))
        XCTAssertFalse(resp.isSuccess())
        XCTAssertEqual(404, resp.httpStatus)
        XCTAssertEqual("404", resp.code)
        XCTAssertEqual("资源不存在", resp.msg)
    }

    func test_nonEnvelopeBody_passesThroughWithDefaultCode() async {
        fake.rawResponse(200, #"{"name":"manifest","version":"1.0.0"}"#)
        let resp = await client.execute(client.newRequest("/manifest.json"))
        XCTAssertTrue(resp.isSuccess())
        XCTAssertEqual("000000", resp.code)
        XCTAssertEqual("1.0.0", resp.data?["version"]?.stringValue)
    }

    func test_retry_failsTwiceThenSucceeds() async {
        fake.envelopeResponse(200, #"{"code":"000000","msg":"ok"}"#)
        fake.failFirstCount = 2
        fake.failError = NSError(domain: "test", code: 1,
                                 userInfo: [NSLocalizedDescriptionKey: "connection reset"])
        let config = client.config
        XCTAssertEqual(2, config.retryCount)
        let resp = await client.execute(client.newRequest("/x"))
        XCTAssertTrue(resp.isSuccess())
        XCTAssertEqual(3, fake.sendCount)
    }

    func test_retryExhausted_returnsNetworkError() async {
        fake.failFirstCount = 10 // 永远失败
        fake.failError = NSError(domain: "test", code: 1,
                                 userInfo: [NSLocalizedDescriptionKey: "connection refused"])
        let resp = await client.execute(client.newRequest("/x"))
        XCTAssertFalse(resp.isSuccess())
        XCTAssertEqual("\(HttpErrorCode.networkError.rawValue)", resp.code)
        XCTAssertEqual(0, resp.httpStatus)
        XCTAssertEqual(3, fake.sendCount) // 1 + 2 retries
    }

    func test_timeoutError_mapsToTimeoutCode() async {
        fake.failFirstCount = 10
        fake.failError = NSError(domain: "test", code: 1,
                                 userInfo: [NSLocalizedDescriptionKey: "Timeout after 5000ms"])
        let resp = await client.execute(client.newRequest("/x"))
        XCTAssertEqual("\(HttpErrorCode.timeoutError.rawValue)", resp.code)
    }

    func test_urlErrorTimedOut_mapsToTimeoutCode() async {
        fake.failFirstCount = 10
        fake.failError = URLError(.timedOut)
        let resp = await client.execute(client.newRequest("/x"))
        XCTAssertEqual("\(HttpErrorCode.timeoutError.rawValue)", resp.code)
        XCTAssertTrue(resp.msg.contains("请求超时"))
    }

    func test_headerMerge_requestOverridesConfig() async {
        fake.envelopeResponse(200, #"{"code":"000000"}"#)
        let config = client.config
        config.headers["X-Common"] = "1"
        config.headers["X-Over"] = "config"
        _ = await client.execute(client.newRequest("/x", RequestOptions(
            headers: ["X-Over": "req", "X-Only": "r"])))
        let sent = fake.requests[0].headers
        XCTAssertEqual("1", sent["X-Common"])
        XCTAssertEqual("req", sent["X-Over"])
        XCTAssertEqual("r", sent["X-Only"])
    }

    func test_getUrlParams_encodedAndAppended() async {
        fake.envelopeResponse(200, #"{"code":"000000"}"#)
        _ = await client.execute(client.newRequest("/items", RequestOptions(
            params: ["a": "1", "b": "2 3"])))
        XCTAssertEqual("https://api.test.com/items?a=1&b=2%203", fake.requests[0].url)
    }

    func test_urlEncoding_pinsReservedChars() {
        // 与 Android/ArkTS 对齐：空格 %20（非 +）、& = ? # 必须编码
        let config = HttpConfig()
        let req = HttpRequest(url: "/search", options: RequestOptions(params: ["q": "a b&c=d"]))
        let full = Call.buildFullUrl(req, config: config)
        XCTAssertEqual("/search?q=a%20b%26c%3Dd", full)
    }

    func test_urlGuardBlock_doesNotHitAdapter() async {
        let config = HttpConfig() // 无 baseUrl，用绝对 URL 测守卫
        config.allowedDomains = ["foo.com"]
        config.retryDelay = 10
        let guardClient = HttpClient(config, adapter: fake)
        let resp = await guardClient.execute(guardClient.newRequest("http://evil.com/steal"))
        XCTAssertFalse(resp.isSuccess())
        XCTAssertEqual("\(HttpErrorCode.urlBlocked.rawValue)", resp.code)
        XCTAssertEqual(0, fake.sendCount)
        XCTAssertTrue(resp.msg.contains("出站守卫"))
    }

    func test_urlGuard_allowedDomain_passes() async {
        fake.envelopeResponse(200, #"{"code":"000000"}"#)
        let config = HttpConfig() // 无 baseUrl，用绝对 URL 测守卫
        config.allowedDomains = ["foo.com"]
        config.retryDelay = 10
        let guardClient = HttpClient(config, adapter: fake)
        let resp = await guardClient.execute(guardClient.newRequest("https://api.foo.com/x"))
        XCTAssertTrue(resp.isSuccess())
        XCTAssertEqual(1, fake.sendCount)
    }

    func test_interceptors_requestOrder_responseReverse() async {
        fake.envelopeResponse(200, #"{"code":"000000"}"#)
        let log = SharedLog()
        client.addInterceptor(RecordingInterceptor("A", log: log))
        client.addInterceptor(RecordingInterceptor("B", log: log))
        _ = await client.execute(client.newRequest("/x"))
        XCTAssertEqual(["A:req", "B:req", "B:resp", "A:resp"], log.entries)
    }

    func test_requestTimeout_overridesConfig() async {
        fake.envelopeResponse(200, #"{"code":"000000"}"#)
        let config = client.config
        config.connectTimeout = 5000
        config.readTimeout = 6000
        _ = await client.execute(
            client.newRequest("/x").setTimeout(connectTimeout: 111, readTimeout: 222))
        XCTAssertEqual(111, fake.requests[0].connectTimeout)
        XCTAssertEqual(222, fake.requests[0].readTimeout)
        // 不覆盖时走 config
        _ = await client.execute(client.newRequest("/y"))
        XCTAssertEqual(5000, fake.requests[1].connectTimeout)
        XCTAssertEqual(6000, fake.requests[1].readTimeout)
    }
}
