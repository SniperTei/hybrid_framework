import XCTest
@testable import CoconutNetwork

/// 一发式便利 API + bytes 模式（对齐 Android coconut-network v1.1.0 HttpClientTest）
final class HttpClientTests: XCTestCase {

    private var fake: FakeAdapter!
    private var client: HttpClient!

    override func setUp() {
        super.setUp()
        NetworkLog.silence()
        fake = FakeAdapter()
        let config = HttpConfig()
        config.baseUrl = "https://api.test.com"
        config.retryDelay = 10
        client = HttpClient(config, adapter: fake)
    }

    func test_oneShotGet_envelope200() async {
        fake.envelopeResponse(200, #"{"code":"000000","msg":"ok","data":{"id":7}}"#)
        let resp = await client.get("/users/1")
        XCTAssertTrue(resp.isSuccess())
        XCTAssertEqual("GET", fake.requests[0].method)
        XCTAssertEqual(7, resp.data?["id"]?.intValue)
    }

    func test_oneShotPost_bodyDelivered() async {
        fake.envelopeResponse(200, #"{"code":"000000","msg":"ok","data":null}"#)
        let resp = await client.post("/users", body: .string("payload"))
        XCTAssertTrue(resp.isSuccess())
        XCTAssertEqual("POST", fake.requests[0].method)
        XCTAssertEqual("\"payload\"", fake.requests[0].body?.serializedString())
    }

    func test_oneShotPutDelete_methods() async {
        _ = await client.put("/users/1", body: .string("u"))
        XCTAssertEqual("PUT", fake.requests[0].method)
        _ = await client.delete("/users/1")
        XCTAssertEqual("DELETE", fake.requests[1].method)
    }

    func test_oneShotGet_paramsBecomeQuery() async {
        fake.envelopeResponse(200, #"{"code":"000000"}"#)
        _ = await client.get("/search", options: RequestOptions(params: ["q": "coconut"]))
        let url = fake.requests[0].url
        XCTAssertTrue(url.hasPrefix("https://api.test.com/search?"))
        XCTAssertTrue(url.contains("q=coconut"))
    }

    func test_oneShotGet_timeoutOverride() async {
        fake.envelopeResponse(200, #"{"code":"000000"}"#)
        _ = await client.get("/slow", options: RequestOptions(connectTimeout: 5000, readTimeout: 9000))
        XCTAssertEqual(5000, fake.requests[0].connectTimeout)
        XCTAssertEqual(9000, fake.requests[0].readTimeout)
    }

    func test_bytes200_rawDataPassthrough() async {
        let payload = Data([1, 2, 3, 4, 5])
        fake.bytesResponse(200, payload)
        let resp = await client.get("/file.bin", options: RequestOptions(responseType: .bytes))

        XCTAssertTrue(resp.isSuccess())
        XCTAssertEqual("000000", resp.code)
        XCTAssertEqual(payload, resp.rawData)
        XCTAssertNil(resp.data)
    }

    func test_bytes404_httpError() async {
        fake.bytesResponse(404, Data([0]))
        let resp = await client.get("/missing.bin", options: RequestOptions(responseType: .bytes))

        XCTAssertFalse(resp.isSuccess())
        XCTAssertEqual("404", resp.code)
        XCTAssertEqual("资源不存在", resp.msg)
    }

    func test_bytesNonEnvelopeNoSniffing() async {
        // bytes 内容恰为 envelope 形状的 JSON 也不进 envelope 分支（无嗅探）
        let envelopeBytes = Data(#"{"code":"000000","msg":"ok","data":{"id":1}}"#.utf8)
        fake.bytesResponse(200, envelopeBytes)
        let resp = await client.get("/manifest.json", options: RequestOptions(responseType: .bytes))

        XCTAssertTrue(resp.isSuccess())
        XCTAssertEqual(envelopeBytes, resp.rawData)
        XCTAssertNil(resp.data)
    }

    func test_bytesAdapterRequestCarriesResponseType() async {
        fake.bytesResponse(200, Data([9]))
        _ = await client.get("/blob", options: RequestOptions(responseType: .bytes))
        XCTAssertEqual(.bytes, fake.requests[0].responseType)

        fake.envelopeResponse(200, #"{"code":"000000"}"#)
        _ = await client.get("/api")
        XCTAssertEqual(.json, fake.requests[1].responseType)
    }

    func test_mockShortCircuit_bytesRequest_rawDataNull() async {
        // 已知限制钉死：mock 短路不感知 responseType —— bytes 请求命中 mock
        // 返回 object data、rawData=nil（Android/Harmony 引擎同样限制）
        fake.envelopeResponse(200, #"{"code":"000000"}"#)
        let resp = await client.execute(
            client.newRequest("/mocked.bin", RequestOptions(responseType: .bytes))
                .enableMocking(.data(.string("mock-data")))
        )

        XCTAssertTrue(resp.isSuccess())
        XCTAssertEqual(0, fake.sendCount) // 未落 adapter
        XCTAssertNil(resp.rawData)
        XCTAssertEqual("\"mock-data\"", resp.data?.serializedString())
    }
}
