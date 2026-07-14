import XCTest
@testable import CoconutSDK

final class BridgeResponseTests: XCTestCase {

    func testSuccessHasSuccessCodeAndMessage() {
        let resp = BridgeResponse.success(id: "abc")
        XCTAssertEqual(resp.code, ErrorCode.SUCCESS)
        XCTAssertEqual(resp.message, "success")
        XCTAssertEqual(resp.id, "abc")
        XCTAssertEqual(resp.jsonrpc, "2.0")
        XCTAssertTrue(resp.isSuccess)
    }

    func testSuccessCarriesResult() {
        let resp = BridgeResponse.success(id: "1", result: ["value": 42])
        XCTAssertEqual(resp.code, ErrorCode.SUCCESS)
        XCTAssertTrue(resp.isSuccess)
    }

    func testErrorPassesThroughFields() {
        let resp = BridgeResponse.error(id: "x", code: "200001", message: "boom")
        XCTAssertEqual(resp.id, "x")
        XCTAssertEqual(resp.code, "200001")
        XCTAssertEqual(resp.message, "boom")
        XCTAssertFalse(resp.isSuccess)
    }

    func testParseErrorFactory() {
        let resp = BridgeResponse.parseError(id: "p")
        XCTAssertEqual(resp.code, ErrorCode.PARSE_ERROR)
        XCTAssertFalse(resp.isSuccess)
    }

    func testInvalidRequestFactory() {
        let resp = BridgeResponse.invalidRequest(id: "i")
        XCTAssertEqual(resp.code, ErrorCode.INVALID_REQUEST)
    }

    func testMethodNotFoundFactory() {
        let resp = BridgeResponse.methodNotFound(id: "m", method: "foo.bar")
        XCTAssertEqual(resp.code, ErrorCode.METHOD_NOT_FOUND)
        XCTAssertTrue(resp.message.contains("foo.bar"))
    }

    func testInvalidParamsFactory() {
        let resp = BridgeResponse.invalidParams(id: "ip")
        XCTAssertEqual(resp.code, ErrorCode.INVALID_PARAMS)
    }

    func testInternalErrorFactory() {
        let resp = BridgeResponse.internalError(id: "ie")
        XCTAssertEqual(resp.code, ErrorCode.INTERNAL_ERROR)
    }

    func testToJSONRoundtripsCoreFields() throws {
        let resp = BridgeResponse.success(id: "roundtrip", result: ["k": "v"])
        let json = resp.toJSON()
        let data = json.data(using: .utf8)!

        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(parsed["jsonrpc"] as? String, "2.0")
        XCTAssertEqual(parsed["id"] as? String, "roundtrip")
        XCTAssertEqual(parsed["code"] as? String, ErrorCode.SUCCESS)
        XCTAssertEqual(parsed["message"] as? String, "success")

        let result = parsed["result"] as? [String: Any]
        XCTAssertEqual(result?["k"] as? String, "v")
    }

    func testToJSONIncludesNullResultForError() throws {
        let resp = BridgeResponse.error(id: "n", code: "200001", message: "fail")
        let json = resp.toJSON()
        let data = json.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertTrue(JSONSerialization.isValidJSONObject(parsed))
        // result should be NSNull
        XCTAssertEqual(parsed["result"] as? NSNull, NSNull())
    }

    func testIsSuccessGetterForError() {
        let resp = BridgeResponse.error(id: "x", code: "200001", message: "m")
        XCTAssertFalse(resp.isSuccess)
    }
}
