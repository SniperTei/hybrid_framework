import XCTest
@testable import CoconutSDK

final class ErrorCodeTests: XCTestCase {

    /// All declared error codes — kept in sync with ErrorCode.swift.
    private let allCodes: [(name: String, code: String)] = [
        ("SUCCESS", ErrorCode.SUCCESS),
        ("PARSE_ERROR", ErrorCode.PARSE_ERROR),
        ("INVALID_REQUEST", ErrorCode.INVALID_REQUEST),
        ("METHOD_NOT_FOUND", ErrorCode.METHOD_NOT_FOUND),
        ("INVALID_PARAMS", ErrorCode.INVALID_PARAMS),
        ("INTERNAL_ERROR", ErrorCode.INTERNAL_ERROR),
        ("UNKNOWN_COMPONENT", ErrorCode.UNKNOWN_COMPONENT),
        ("UNKNOWN_FUNCTION", ErrorCode.UNKNOWN_FUNCTION),
        ("PERMISSION_DENIED", ErrorCode.PERMISSION_DENIED),
        ("TIMEOUT", ErrorCode.TIMEOUT),
        ("CANCELLED", ErrorCode.CANCELLED),
        ("DOMAIN_NOT_ALLOWED", ErrorCode.DOMAIN_NOT_ALLOWED),
        ("PARAM_VALIDATION_FAILED", ErrorCode.PARAM_VALIDATION_FAILED),
        ("COMPONENT_NOT_INITIALIZED", ErrorCode.COMPONENT_NOT_INITIALIZED),
        ("RATE_LIMIT_EXCEEDED", ErrorCode.RATE_LIMIT_EXCEEDED),
        ("BRIDGE_TOKEN_INVALID", ErrorCode.BRIDGE_TOKEN_INVALID),
    ]

    private let sixDigitPattern = #"^\d{6}$"#

    func testAllCodesAreSixDigitStrings() {
        for (name, code) in allCodes {
            XCTAssertNotNil(code.range(of: sixDigitPattern, options: .regularExpression),
                            "\(name) (\(code)) is not a 6-digit string")
        }
    }

    func testCodesAreUnique() {
        var seen = Set<String>()
        for (name, code) in allCodes {
            XCTAssertTrue(seen.insert(code).inserted, "Duplicate code \(code) for \(name)")
        }
    }

    func testSuccessIsZero() {
        XCTAssertEqual(ErrorCode.SUCCESS, "000000")
    }

    func testGetDescriptionReturnsNonEmptyForKnownCodes() {
        for (name, code) in allCodes where name != "SUCCESS" {
            let desc = ErrorCode.getDescription(code)
            XCTAssertFalse(desc.isEmpty, "Description for \(name) (\(code)) is empty")
            XCTAssertNotEqual(desc, "Unknown error", "Description for \(name) (\(code)) fell through to Unknown")
        }
    }

    func testGetDescriptionForUnknownCode() {
        XCTAssertEqual(ErrorCode.getDescription("999999"), "Unknown error")
        XCTAssertEqual(ErrorCode.getDescription("not-a-code"), "Unknown error")
        XCTAssertEqual(ErrorCode.getDescription(""), "Unknown error")
    }

    func testStandardErrorRange() {
        let standardCodes = [
            ErrorCode.PARSE_ERROR, ErrorCode.INVALID_REQUEST, ErrorCode.METHOD_NOT_FOUND,
            ErrorCode.INVALID_PARAMS, ErrorCode.INTERNAL_ERROR
        ]
        for code in standardCodes {
            XCTAssertTrue(code.hasPrefix("10000"), "\(code) not in 100001-100005 range")
        }
    }

    func testBusinessErrorRange() {
        let businessCodes = [
            ErrorCode.UNKNOWN_COMPONENT, ErrorCode.UNKNOWN_FUNCTION, ErrorCode.PERMISSION_DENIED,
            ErrorCode.TIMEOUT, ErrorCode.CANCELLED, ErrorCode.DOMAIN_NOT_ALLOWED,
            ErrorCode.PARAM_VALIDATION_FAILED, ErrorCode.COMPONENT_NOT_INITIALIZED,
            ErrorCode.RATE_LIMIT_EXCEEDED
        ]
        for code in businessCodes {
            XCTAssertTrue(code.hasPrefix("20000"), "\(code) not in 200001-200009 range")
        }
    }

    func testSecurityErrorRange() {
        let securityCodes = [
            ErrorCode.BRIDGE_TOKEN_INVALID
        ]
        for code in securityCodes {
            XCTAssertTrue(code.hasPrefix("30000"), "\(code) not in 300001-300004 range")
        }
    }
}
