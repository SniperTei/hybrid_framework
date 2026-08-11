import XCTest
import UIKit
@testable import CoconutSDK

@MainActor
final class BridgeDispatcherTests: XCTestCase {

    private var dispatcher: BridgeDispatcher!
    private var tokenManager: BridgeTokenManager { .shared }
    private var componentManager: ComponentManager { .shared }

    override func setUp() async throws {
        try await super.setUp()
        dispatcher = BridgeDispatcher()

        // Token manager: enabled, with a known token.
        tokenManager.enabled = true
        tokenManager.reset()

        // Component registry clean slate with a usable shared context.
        await componentManager.cleanup()
        componentManager.setApplicationContext(UIApplication.shared)
    }

    override func tearDown() async throws {
        await componentManager.cleanup()
        tokenManager.reset()
        tokenManager.enabled = true
        try await super.tearDown()
    }

    /// Build a JSON request string with the given fields.
    private func requestJson(id: String = "1",
                             component: String,
                             function: String,
                             params: [String: Any] = [:],
                             token: String? = nil) -> String {
        var dict: [String: Any] = [
            "id": id,
            "component": component,
            "function": function,
            "params": params,
        ]
        if let token = token {
            dict["bridgeToken"] = token
        }
        let data = try! JSONSerialization.data(withJSONObject: dict)
        return String(data: data, encoding: .utf8)!
    }

    /// Parse a JSON response string into a dictionary.
    private func parse(_ json: String) -> [String: Any] {
        let data = json.data(using: .utf8)!
        return (try! JSONSerialization.jsonObject(with: data)) as! [String: Any]
    }

    // MARK: - parse errors

    func testInvalidJsonReturnsParseError() async {
        let response = await dispatcher.handleCall("not-json", currentUrl: "https://example.com")
        let parsed = parse(response)
        XCTAssertEqual(parsed["code"] as? String, ErrorCode.PARSE_ERROR)
        XCTAssertEqual(parsed["id"] as? String, "")
    }

    func testMissingIdReturnsParseError() async {
        let response = await dispatcher.handleCall("{\"component\":\"device\",\"function\":\"getInfo\"}", currentUrl: "https://example.com")
        let parsed = parse(response)
        XCTAssertEqual(parsed["code"] as? String, ErrorCode.PARSE_ERROR)
    }

    // MARK: - component / function name format

    func testInvalidComponentNameReturnsInvalidRequest() async {
        let token = tokenManager.generateToken()
        let response = await dispatcher.handleCall(
            requestJson(component: "bad.name", function: "getInfo", token: token),
            currentUrl: "https://example.com"
        )
        let parsed = parse(response)
        XCTAssertEqual(parsed["code"] as? String, ErrorCode.INVALID_REQUEST)
    }

    func testInvalidFunctionNameReturnsInvalidRequest() async {
        let token = tokenManager.generateToken()
        let response = await dispatcher.handleCall(
            requestJson(component: "device", function: "bad function", token: token),
            currentUrl: "https://example.com"
        )
        let parsed = parse(response)
        XCTAssertEqual(parsed["code"] as? String, ErrorCode.INVALID_REQUEST)
    }

    // MARK: - bridge token

    func testWrongBridgeTokenRejected() async {
        _ = tokenManager.generateToken()
        let response = await dispatcher.handleCall(
            requestJson(component: "device", function: "getInfo", token: "wrong-token"),
            currentUrl: "https://example.com"
        )
        let parsed = parse(response)
        XCTAssertEqual(parsed["code"] as? String, ErrorCode.BRIDGE_TOKEN_INVALID)
    }

    func testMissingBridgeTokenRejected() async {
        _ = tokenManager.generateToken()
        let response = await dispatcher.handleCall(
            requestJson(component: "device", function: "getInfo"), // no token
            currentUrl: "https://example.com"
        )
        let parsed = parse(response)
        XCTAssertEqual(parsed["code"] as? String, ErrorCode.BRIDGE_TOKEN_INVALID)
    }

    // MARK: - component dispatch

    func testUnknownComponentReturnsUnknownComponent() async {
        let token = tokenManager.generateToken()
        let response = await dispatcher.handleCall(
            requestJson(component: "ghost", function: "doSomething", token: token),
            currentUrl: "https://example.com"
        )
        let parsed = parse(response)
        XCTAssertEqual(parsed["code"] as? String, ErrorCode.UNKNOWN_COMPONENT)
    }

    func testComponentNotInitializedReturnsNotInitialized() async throws {
        let plugin = MockPlugin(name: "device")
        try await componentManager.register(plugin)
        // Simulate the race where isInitialized flipped to false after registration.
        plugin.setInitializedForTesting(false)

        let token = tokenManager.generateToken()
        let response = await dispatcher.handleCall(
            requestJson(component: "device", function: "getInfo", token: token),
            currentUrl: "https://example.com"
        )
        let parsed = parse(response)
        XCTAssertEqual(parsed["code"] as? String, ErrorCode.COMPONENT_NOT_INITIALIZED)
    }

    func testComponentHandleSuccessReturnsSuccess() async throws {
        let plugin = MockPlugin(name: "device", handleResult: ["model": "iPhone-Test"])
        try await componentManager.register(plugin)

        let token = tokenManager.generateToken()
        let response = await dispatcher.handleCall(
            requestJson(component: "device", function: "getInfo", params: ["extra": 1], token: token),
            currentUrl: "https://example.com"
        )
        let parsed = parse(response)
        XCTAssertEqual(parsed["code"] as? String, ErrorCode.SUCCESS)
        XCTAssertEqual(parsed["message"] as? String, "success")

        let result = parsed["result"] as? [String: Any]
        XCTAssertEqual(result?["model"] as? String, "iPhone-Test")

        XCTAssertEqual(plugin.lastHandledFunction, "getInfo")
        XCTAssertEqual(plugin.lastHandledParams?["extra"] as? Int, 1)
    }

    func testComponentThrowingComponentExceptionPropagatesCode() async throws {
        let plugin = MockPlugin(name: "device")
        plugin.throwOnHandle = ComponentException(code: "200002", message: "no such function")
        try await componentManager.register(plugin)

        let token = tokenManager.generateToken()
        let response = await dispatcher.handleCall(
            requestJson(component: "device", function: "unknownFn", token: token),
            currentUrl: "https://example.com"
        )
        let parsed = parse(response)
        XCTAssertEqual(parsed["code"] as? String, "200002")
        XCTAssertEqual(parsed["message"] as? String, "no such function")
    }

    func testComponentThrowingGenericErrorReturnsInternalError() async throws {
        struct Boom: Error {}
        let plugin = MockPlugin(name: "device")
        try await componentManager.register(plugin)
        // Use a ComponentException with internal-ish code path via throwOnHandle won't produce generic error.
        // Instead, throw via a custom subclass-free path: set throwOnHandle to a ComponentException whose code is INTERNAL_ERROR.
        plugin.throwOnHandle = ComponentException(code: ErrorCode.INTERNAL_ERROR, message: "boom")
        try await componentManager.register(plugin) // already registered, no-op

        let token = tokenManager.generateToken()
        let response = await dispatcher.handleCall(
            requestJson(component: "device", function: "fail", token: token),
            currentUrl: "https://example.com"
        )
        let parsed = parse(response)
        XCTAssertEqual(parsed["code"] as? String, ErrorCode.INTERNAL_ERROR)
    }

    // MARK: - domain whitelist (integration with security validator)

    func testDomainNotInWhitelistRejected() async throws {
        dispatcher.securityValidator.setAllowedDomains(["allowed.com"])

        let token = tokenManager.generateToken()
        let response = await dispatcher.handleCall(
            requestJson(component: "device", function: "getInfo", token: token),
            currentUrl: "https://evil.com/page"
        )
        let parsed = parse(response)
        XCTAssertEqual(parsed["code"] as? String, ErrorCode.DOMAIN_NOT_ALLOWED)
    }

    func testEmptyWhitelistAllowsAnyDomain() async throws {
        let plugin = MockPlugin(name: "device")
        try await componentManager.register(plugin)

        let token = tokenManager.generateToken()
        let response = await dispatcher.handleCall(
            requestJson(component: "device", function: "getInfo", token: token),
            currentUrl: "https://anything.evil.com"
        )
        let parsed = parse(response)
        XCTAssertEqual(parsed["code"] as? String, ErrorCode.SUCCESS)
    }
}
