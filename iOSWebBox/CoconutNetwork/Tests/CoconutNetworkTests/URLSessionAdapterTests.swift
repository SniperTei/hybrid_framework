import XCTest
@testable import CoconutNetwork

/// URLSessionAdapter 集成测试（MockURLProtocol stub，对应 Android 的
/// JDK HttpServer 集成测试）
final class URLSessionAdapterTests: XCTestCase {

    private var client: HttpClient!

    override func setUp() {
        super.setUp()
        NetworkLog.silence()
        let config = HttpConfig()
        config.baseUrl = "https://api.test.com"
        config.retryDelay = 10
        client = HttpClient(config, adapter: URLSessionAdapter(session: MockURLProtocol.makeSession()))
    }

    override func tearDown() {
        MockURLProtocol.setHandler(nil)
        super.tearDown()
    }

    func test_statusAndHeaders_parsed() async {
        MockURLProtocol.setHandler { _ in
            (200, ["Content-Type": "application/json", "X-Custom": "abc"],
             Data(#"{"code":"000000","msg":"ok","data":{"id":1},"timestamp":"t1"}"#.utf8))
        }
        let resp = await client.get("/users/1")
        XCTAssertTrue(resp.isSuccess())
        XCTAssertEqual(200, resp.httpStatus)
        XCTAssertEqual("ok", resp.msg)
        XCTAssertEqual("t1", resp.timestamp)
        XCTAssertEqual(1, resp.data?["id"]?.intValue)
        XCTAssertEqual("application/json", resp.headers["Content-Type"])
        XCTAssertEqual("abc", resp.headers["X-Custom"])
    }

    func test_nonEnvelopeBody_wrappedAsStringOrObject() async {
        MockURLProtocol.setHandler { _ in
            (200, ["Content-Type": "application/json"], Data(#"{"version":"1.0.0"}"#.utf8))
        }
        let resp = await client.get("/manifest.json")
        XCTAssertTrue(resp.isSuccess())
        XCTAssertEqual("000000", resp.code)
        XCTAssertEqual("1.0.0", resp.data?["version"]?.stringValue)
    }

    func test_http404_mapsToHttpError() async {
        MockURLProtocol.setHandler { _ in (404, [:], Data("nope".utf8)) }
        let resp = await client.get("/missing")
        XCTAssertFalse(resp.isSuccess())
        XCTAssertEqual("404", resp.code)
        XCTAssertEqual("资源不存在", resp.msg)
    }

    func test_bytesMode_rawBodyDelivered() async {
        let payload = Data([9, 8, 7])
        MockURLProtocol.setHandler { _ in (200, [:], payload) }
        let resp = await client.get("/file.bin", options: RequestOptions(responseType: .bytes))
        XCTAssertTrue(resp.isSuccess())
        XCTAssertEqual(payload, resp.rawData)
        XCTAssertNil(resp.data)
    }

    func test_urlErrorTimedOut_classifiedAsTimeout() async {
        MockURLProtocol.setHandler { _ in throw URLError(.timedOut) }
        let resp = await client.get("/slow")
        XCTAssertFalse(resp.isSuccess())
        XCTAssertEqual("\(HttpErrorCode.timeoutError.rawValue)", resp.code)
        XCTAssertTrue(resp.msg.contains("请求超时"))
    }

    func test_postBody_deliveredWithContentType() async {
        MockURLProtocol.setHandler { _ in (200, [:], Data(#"{"code":"000000"}"#.utf8)) }
        let resp = await client.post("/users", body: .object(["name": .string("n")]))
        XCTAssertTrue(resp.isSuccess())
        let sent = MockURLProtocol.lastRequest
        XCTAssertEqual("POST", sent?.httpMethod)
        XCTAssertEqual("application/json", sent?.value(forHTTPHeaderField: "Content-Type"))
        let bodyText = sent.flatMap(MockURLProtocol.body(of:)).flatMap { String(data: $0, encoding: .utf8) }
        XCTAssertEqual(#"{"name":"n"}"#, normalizeJson(bodyText))
    }
}

private func normalizeJson(_ text: String?) -> String? {
    guard let text, let data = text.data(using: .utf8),
          let any = try? JSONSerialization.jsonObject(with: data),
          let normalized = try? JSONSerialization.data(withJSONObject: any) else { return nil }
    return String(data: normalized, encoding: .utf8)
}
