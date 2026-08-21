import XCTest
@testable import CoconutNetwork

final class UrlGuardTests: XCTestCase {

    func test_http_withEmptyDomains_allows() {
        let r = UrlGuard.validate("http://anything.example.com/path", allowedDomains: [])
        XCTAssertTrue(r.allowed)
    }

    func test_https_exactHostMatch_allows() {
        let r = UrlGuard.validate("https://foo.com/api", allowedDomains: ["foo.com"])
        XCTAssertTrue(r.allowed)
    }

    func test_subdomainSuffixMatch_allows() {
        let r = UrlGuard.validate("https://api.foo.com/api", allowedDomains: ["foo.com"])
        XCTAssertTrue(r.allowed)
    }

    func test_subdomainSuffixMatch_multiLevel_allows() {
        let r = UrlGuard.validate("https://a.b.foo.com/api", allowedDomains: ["foo.com"])
        XCTAssertTrue(r.allowed)
    }

    func test_suffixAttack_isBlocked() {
        let r = UrlGuard.validate("https://api.foo.com.evil.com/api", allowedDomains: ["foo.com"])
        XCTAssertFalse(r.allowed)
        XCTAssertTrue(r.reason.contains("allowedDomains"))
    }

    func test_portIsStrippedFromHost() {
        let r = UrlGuard.validate("https://api.foo.com:8443/api", allowedDomains: ["foo.com"])
        XCTAssertTrue(r.allowed)
    }

    func test_caseInsensitiveSchemeAndHost() {
        let r = UrlGuard.validate("HTTP://API.FOO.COM/api", allowedDomains: ["FOO.com"])
        XCTAssertTrue(r.allowed)
    }

    func test_coconutScheme_isBlocked() {
        let r = UrlGuard.validate("coconut://demo/index.html", allowedDomains: [])
        XCTAssertFalse(r.allowed)
        XCTAssertTrue(r.reason.contains("scheme"))
    }

    func test_fileScheme_isBlocked() {
        let r = UrlGuard.validate("file:///etc/passwd", allowedDomains: [])
        XCTAssertFalse(r.allowed)
    }

    func test_javascriptUri_isBlocked() {
        let r = UrlGuard.validate("javascript:alert(1)", allowedDomains: [])
        XCTAssertFalse(r.allowed)
    }

    func test_noScheme_isBlocked() {
        let r = UrlGuard.validate("www.foo.com/path", allowedDomains: ["foo.com"])
        XCTAssertFalse(r.allowed)
    }

    func test_emptyHost_isBlocked() {
        let r = UrlGuard.validate("http:///path", allowedDomains: [])
        XCTAssertFalse(r.allowed)
    }

    func test_hostNotInWhitelist_isBlocked() {
        let r = UrlGuard.validate("https://evil.com/api", allowedDomains: ["foo.com", "bar.com"])
        XCTAssertFalse(r.allowed)
        XCTAssertTrue(r.reason.contains("evil.com"))
    }
}
