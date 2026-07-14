import XCTest
@testable import CoconutSDK

final class BridgeTokenManagerTests: XCTestCase {

    private var manager: BridgeTokenManager { .shared }

    override func setUp() {
        super.setUp()
        manager.enabled = true
        manager.reset()
    }

    override func tearDown() {
        manager.reset()
        manager.enabled = true
        super.tearDown()
    }

    func testInitialTokenIsEmptyAndEmptyTokenValidates() {
        manager.reset()
        XCTAssertEqual(manager.getToken(), "")
        // Empty token means "not yet generated" → any request passes
        XCTAssertTrue(manager.validateToken(""))
        XCTAssertTrue(manager.validateToken("anything"))
    }

    func testGenerateTokenReturnsNonEmpty() {
        let token = manager.generateToken()
        XCTAssertFalse(token.isEmpty)
        XCTAssertEqual(manager.getToken(), token)
    }

    func testGenerateTokenProducesDifferentValues() {
        let t1 = manager.generateToken()
        let t2 = manager.generateToken()
        XCTAssertNotEqual(t1, t2)
    }

    func testValidateCorrectTokenPasses() {
        let token = manager.generateToken()
        XCTAssertTrue(manager.validateToken(token))
    }

    func testValidateWrongTokenFails() {
        let token = manager.generateToken()
        XCTAssertFalse(manager.validateToken("wrong-token"))
        XCTAssertFalse(manager.validateToken(token + "x"))
    }

    func testDisabledAllowsAnyToken() {
        manager.generateToken()
        manager.enabled = false
        XCTAssertTrue(manager.validateToken("anything"))
        XCTAssertTrue(manager.validateToken(""))
    }

    func testResetClearsToken() {
        let token = manager.generateToken()
        XCTAssertFalse(token.isEmpty)
        manager.reset()
        XCTAssertEqual(manager.getToken(), "")
        // After reset, token is empty → any token passes again
        XCTAssertTrue(manager.validateToken("whatever"))
    }
}
