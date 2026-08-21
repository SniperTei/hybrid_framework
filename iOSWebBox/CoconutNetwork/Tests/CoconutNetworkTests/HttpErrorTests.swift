import XCTest
@testable import CoconutNetwork

final class HttpErrorTests: XCTestCase {

    func test_isNetworkError_truthTable() {
        XCTAssertTrue(HttpError.isNetworkError(-1001))   // networkError
        XCTAssertTrue(HttpError.isNetworkError(-1002))   // timeoutError
        XCTAssertTrue(HttpError.isNetworkError(-1004))   // urlBlocked（传输层拒绝）
        XCTAssertFalse(HttpError.isNetworkError(-2001))  // tokenExpired
        XCTAssertFalse(HttpError.isNetworkError(500))
    }

    func test_isTokenError_truthTable() {
        XCTAssertTrue(HttpError.isTokenError(-2001))
        XCTAssertTrue(HttpError.isTokenError(-2002))
        XCTAssertFalse(HttpError.isTokenError(-1001))
        XCTAssertFalse(HttpError.isTokenError(-3001))
    }

    func test_isRetryable_truthTable() {
        XCTAssertTrue(HttpError.isRetryable(-1001))       // networkError
        XCTAssertTrue(HttpError.isRetryable(-1002))       // timeoutError
        XCTAssertFalse(HttpError.isRetryable(-1003))      // sslError
        XCTAssertFalse(HttpError.isRetryable(-1004))      // urlBlocked
        XCTAssertFalse(HttpError.isRetryable(-2001))
    }

    func test_urlBlockedCode_existsInEnum() {
        XCTAssertEqual(-1004, HttpErrorCode.urlBlocked.rawValue)
    }
}
