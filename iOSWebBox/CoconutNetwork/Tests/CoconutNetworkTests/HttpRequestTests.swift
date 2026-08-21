import XCTest
@testable import CoconutNetwork

final class HttpRequestTests: XCTestCase {

    func test_defaultMethod_isGet() {
        let req = HttpRequest(url: "/x")
        XCTAssertEqual(.get, req.method)
        XCTAssertEqual(-1, req.connectTimeout)
        XCTAssertEqual(-1, req.readTimeout)
    }

    func test_postParams_becomeBody() {
        let req = HttpRequest(url: "/x", options: RequestOptions(method: .post, params: ["a": "1"]))
        XCTAssertEqual("1", req.body?["a"]?.stringValue)
        XCTAssertTrue(req.params.isEmpty)
    }

    func test_putParams_becomeBody() {
        let req = HttpRequest(url: "/x", options: RequestOptions(method: .put, params: ["a": "1"]))
        XCTAssertEqual("1", req.body?["a"]?.stringValue)
    }

    func test_getParams_stayAsQuery() {
        let req = HttpRequest(url: "/x", options: RequestOptions(method: .get, params: ["a": "1"]))
        XCTAssertEqual("1", req.params["a"])
        XCTAssertNil(req.body)
    }

    func test_explicitBody_overridesParamsBody() {
        let body = JSONValue.parse(Data(#"{"b": "2"}"#.utf8))!
        let req = HttpRequest(url: "/x", options: RequestOptions(
            method: .post, params: ["a": "1"], body: body))
        XCTAssertEqual(body, req.body)
    }

    func test_chainMethods_returnCopies() {
        let body = JSONValue.parse(Data(#"{"k": "v"}"#.utf8))!
        let req = HttpRequest(url: "/x")
            .setHeader("X-A", "1")
            .setBody(body)
            .setTag("t1")
            .setTimeout(connectTimeout: 100, readTimeout: 200)
        // 原值不受影响（值语义）
        let untouched = HttpRequest(url: "/x")
        XCTAssertTrue(untouched.headers.isEmpty)
        // 链式结果生效
        XCTAssertEqual("1", req.headers["X-A"])
        XCTAssertEqual(body, req.body)
        XCTAssertEqual("t1", req.tag)
        XCTAssertEqual(100, req.connectTimeout)
        XCTAssertEqual(200, req.readTimeout)
    }

    func test_newRequest_appliesOptions() {
        let client = HttpClient(HttpConfig())
        let req = client.newRequest("/blob", RequestOptions(readTimeout: 5000, responseType: .bytes))
        XCTAssertEqual(HttpResponseType.bytes, req.responseType)
        XCTAssertEqual(5000, req.readTimeout)
        // 一发式内部即用此路径（Kotlin 侧的 buildCall 绑定校验在 Swift 无此概念）
        let other = client.newRequest("/y")
        XCTAssertEqual(.json, other.responseType)
    }
}
