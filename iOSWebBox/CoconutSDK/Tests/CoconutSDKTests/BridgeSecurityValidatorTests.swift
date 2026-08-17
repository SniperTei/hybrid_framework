import XCTest
@testable import CoconutSDK

final class BridgeSecurityValidatorTests: XCTestCase {

    private var validator: BridgeSecurityValidator!

    override func setUp() {
        super.setUp()
        validator = BridgeSecurityValidator()
    }

    // MARK: - validateDomain

    func testEmptyWhitelistAllowsAnyDomain() {
        XCTAssertEqual(validator.validateDomain("https://evil.com/path").isValid, true)
        XCTAssertEqual(validator.validateDomain("about:blank").isValid, true)
    }

    func testExactDomainMatchPasses() {
        validator.setAllowedDomains(["example.com"])
        XCTAssertTrue(validator.validateDomain("https://example.com/page").isValid)
    }

    func testSubdomainMatchPasses() {
        validator.setAllowedDomains(["example.com"])
        XCTAssertTrue(validator.validateDomain("https://sub.example.com/page").isValid)
        XCTAssertTrue(validator.validateDomain("https://a.b.example.com/").isValid)
    }

    func testNonWhitelistedHostRejected() {
        validator.setAllowedDomains(["example.com"])
        let result = validator.validateDomain("https://evil.com/page")
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.message.contains("evil.com"))
    }

    func testUnresolvableHostRejected() {
        validator.setAllowedDomains(["example.com"])
        // String with no scheme and no host
        let result = validator.validateDomain("not a url")
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.message.contains("Cannot extract host"))
    }

    func testLocalSchemesExemptFromWhitelist() {
        validator.setAllowedDomains(["example.com"])
        // Offline-package / bundled-content schemes carry no meaningful host
        XCTAssertTrue(validator.validateDomain("coconut://demo/index.html").isValid)
        XCTAssertTrue(validator.validateDomain("file:///var/containers/page.html").isValid)
    }

    func testAddAllowedDomainAccumulates() {
        validator.addAllowedDomain("a.com")
        validator.addAllowedDomain("b.com")
        let domains = Set(validator.getAllowedDomains())
        XCTAssertEqual(domains, Set(["a.com", "b.com"]))
    }

    func testSetAllowedDomainsReplaces() {
        validator.addAllowedDomain("a.com")
        validator.setAllowedDomains(["b.com", "c.com"])
        let domains = Set(validator.getAllowedDomains())
        XCTAssertEqual(domains, Set(["b.com", "c.com"]))
    }

    // MARK: - validateParamsSize

    func testParamsSizeUnderLimitPasses() {
        validator.maxParamsSize = 100
        XCTAssertTrue(validator.validateParamsSize(String(repeating: "a", count: 50)).isValid)
    }

    func testParamsSizeAtLimitPasses() {
        validator.maxParamsSize = 100
        XCTAssertTrue(validator.validateParamsSize(String(repeating: "a", count: 100)).isValid)
    }

    func testParamsSizeOverLimitRejected() {
        validator.maxParamsSize = 100
        let result = validator.validateParamsSize(String(repeating: "a", count: 101))
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.message.contains("exceeds limit"))
    }

    // MARK: - checkRateLimit

    func testRateLimitAllowsUpToLimit() {
        validator.rateLimitPerMethod = 3
        for _ in 0..<3 {
            XCTAssertTrue(validator.checkRateLimit("device.getInfo").isValid)
        }
    }

    func testRateLimitRejectsOverLimit() {
        validator.rateLimitPerMethod = 2
        XCTAssertTrue(validator.checkRateLimit("device.getInfo").isValid)
        XCTAssertTrue(validator.checkRateLimit("device.getInfo").isValid)
        let result = validator.checkRateLimit("device.getInfo")
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.message.contains("Rate limit exceeded"))
    }

    func testRateLimitIsPerMethod() {
        validator.rateLimitPerMethod = 1
        XCTAssertTrue(validator.checkRateLimit("device.getInfo").isValid)
        XCTAssertTrue(validator.checkRateLimit("storage.set").isValid)
        // Different methods don't interfere
    }

    func testRateLimitResetsAcrossWindow() {
        validator.rateLimitPerMethod = 2
        validator.rateLimitWindowMs = 100 // 100ms window for testing

        XCTAssertTrue(validator.checkRateLimit("device.getInfo").isValid)
        XCTAssertTrue(validator.checkRateLimit("device.getInfo").isValid)
        XCTAssertFalse(validator.checkRateLimit("device.getInfo").isValid)

        // Wait for window to roll over
        Thread.sleep(forTimeInterval: 0.15)

        XCTAssertTrue(validator.checkRateLimit("device.getInfo").isValid)
    }

    func testResetRateLimitClearsCounters() {
        validator.rateLimitPerMethod = 1
        XCTAssertTrue(validator.checkRateLimit("device.getInfo").isValid)
        XCTAssertFalse(validator.checkRateLimit("device.getInfo").isValid)

        validator.resetRateLimit()
        XCTAssertTrue(validator.checkRateLimit("device.getInfo").isValid)
    }
}
