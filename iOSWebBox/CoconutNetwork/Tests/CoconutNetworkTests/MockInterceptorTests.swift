import XCTest
@testable import CoconutNetwork

final class MockInterceptorTests: XCTestCase {

    private var fake: FakeAdapter!
    private var client: HttpClient!
    private var mock: MockInterceptor!

    override func setUp() {
        super.setUp()
        NetworkLog.silence()
        fake = FakeAdapter()
        fake.envelopeResponse(200, #"{"code":"000000","msg":"real"}"#)
        mock = MockInterceptor()
        let config = HttpConfig()
        config.baseUrl = "https://api.test.com" // passthrough 用例需完整 URL 过 UrlGuard
        config.retryDelay = 10
        client = HttpClient(config, adapter: fake)
        client.addInterceptor(mock)
    }

    func test_exactUrlHit_returnsMockData_skipsAdapter() async {
        mock.addRule(MockRule(url: "/api/user", method: .get,
                              data: .object(["name": .string("test")])))
        let resp = await client.execute(client.newRequest("/api/user"))
        XCTAssertTrue(resp.isSuccess())
        XCTAssertEqual(200, resp.httpStatus)
        XCTAssertEqual("test", resp.data?["name"]?.stringValue)
        XCTAssertEqual(0, fake.sendCount)
    }

    func test_prefixUrlHit_withWildcard() async {
        mock.addRule(MockRule(url: "/api/items*", data: .object(["list": .array([])])))
        let resp = await client.execute(client.newRequest("/api/items/1"))
        XCTAssertTrue(resp.isSuccess())
        XCTAssertEqual(0, fake.sendCount)
    }

    func test_methodMismatch_passesThroughToAdapter() async {
        mock.addRule(MockRule(url: "/api/user", method: .post, data: .object([:])))
        let resp = await client.execute(client.newRequest("/api/user")) // GET
        XCTAssertEqual(1, fake.sendCount)
        XCTAssertEqual("real", resp.msg)
    }

    func test_urlMismatch_passesThroughToAdapter() async {
        mock.addRule(MockRule(url: "/api/other", data: .object([:])))
        _ = await client.execute(client.newRequest("/api/user"))
        XCTAssertEqual(1, fake.sendCount)
    }

    func test_errorRule_mockFailures_withStatusAndCode() async {
        mock.addRule(MockRule(url: "/api/login", httpStatus: 500, code: "500000", msg: "mock fail"))
        let resp = await client.execute(client.newRequest("/api/login", RequestOptions(method: .post)))
        XCTAssertFalse(resp.isSuccess())
        XCTAssertEqual(500, resp.httpStatus)
        XCTAssertEqual("500000", resp.code)
        XCTAssertEqual("mock fail", resp.msg)
        XCTAssertEqual(0, fake.sendCount)
    }

    func test_mockRule_anyMethod_whenOmitted() async {
        mock.addRule(MockRule(url: "/api/any", data: .object(["ok": .number(1)])))
        let respGet = await client.execute(client.newRequest("/api/any"))
        let respPost = await client.execute(client.newRequest("/api/any", RequestOptions(method: .post)))
        XCTAssertTrue(respGet.isSuccess())
        XCTAssertTrue(respPost.isSuccess())
        XCTAssertEqual(0, fake.sendCount)
    }

    func test_clearAll_removesRules() async {
        mock.addRule(MockRule(url: "/api/user", data: .object([:])))
        mock.clearAll()
        _ = await client.execute(client.newRequest("/api/user"))
        XCTAssertEqual(1, fake.sendCount)
    }

    func test_manualEnableMocking_withoutInterceptor() async {
        let bareClient = HttpClient(HttpConfig(), adapter: fake)
        let resp = await bareClient.execute(
            bareClient.newRequest("/api/user").enableMocking(.data(.object(["name": .string("manual")])))
        )
        XCTAssertTrue(resp.isSuccess())
        XCTAssertEqual("manual", resp.data?["name"]?.stringValue)
        XCTAssertEqual(0, fake.sendCount)
    }

    func test_mockSkipsUrlGuard_notBlocked() async {
        // 守卫配置成拦所有，mock 仍应短路成功（mock 不出网）
        let config = HttpConfig()
        config.allowedDomains = ["foo.com"]
        let guardedClient = HttpClient(config, adapter: fake)
        guardedClient.addInterceptor(mock)
        mock.addRule(MockRule(url: "http://evil.com/api", data: .object(["ok": .number(1)])))
        let resp = await guardedClient.execute(guardedClient.newRequest("http://evil.com/api"))
        XCTAssertTrue(resp.isSuccess())
        XCTAssertEqual(0, fake.sendCount)
    }
}
