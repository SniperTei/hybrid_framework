import XCTest
@testable import CoconutSDK

final class CoconutSchemeHandlerTests: XCTestCase {

    // MARK: - parseOfflinePath

    func testParseModuleIdAndPath() {
        let url = URL(string: "coconut://demo/index.html")!
        let parsed = CoconutSchemeHandler.parseOfflinePath(url)
        XCTAssertEqual(parsed?.moduleId, "demo")
        XCTAssertEqual(parsed?.path, "index.html")
    }

    func testParseNestedAssetPath() {
        let url = URL(string: "coconut://demo/assets/index.js")!
        let parsed = CoconutSchemeHandler.parseOfflinePath(url)
        XCTAssertEqual(parsed?.moduleId, "demo")
        XCTAssertEqual(parsed?.path, "assets/index.js")
    }

    func testParseEmptyPathResolvesToEntry() {
        let url = URL(string: "coconut://demo")!
        let parsed = CoconutSchemeHandler.parseOfflinePath(url)
        XCTAssertEqual(parsed?.moduleId, "demo")
        XCTAssertEqual(parsed?.path, "index.html")
    }

    func testParseTrailingSlashResolvesToEntry() {
        let url = URL(string: "coconut://demo/")!
        let parsed = CoconutSchemeHandler.parseOfflinePath(url)
        XCTAssertEqual(parsed?.moduleId, "demo")
        XCTAssertEqual(parsed?.path, "index.html")
    }

    func testParseWrongSchemeReturnsNil() {
        XCTAssertNil(CoconutSchemeHandler.parseOfflinePath(URL(string: "https://demo/index.html")!))
        XCTAssertNil(CoconutSchemeHandler.parseOfflinePath(URL(string: "file:///demo/index.html")!))
    }

    func testParseMissingHostReturnsNil() {
        // coconut://<nothing> — no moduleId to route to
        XCTAssertNil(CoconutSchemeHandler.parseOfflinePath(URL(string: "coconut:///index.html")!))
    }

    // MARK: - mimeType

    func testMimeTypesAlignedWithAndroidTable() {
        XCTAssertEqual(CoconutSchemeHandler.mimeType(forPath: "index.html"), "text/html")
        XCTAssertEqual(CoconutSchemeHandler.mimeType(forPath: "assets/index.css"), "text/css")
        XCTAssertEqual(CoconutSchemeHandler.mimeType(forPath: "assets/index.js"), "application/javascript")
        XCTAssertEqual(CoconutSchemeHandler.mimeType(forPath: "manifest.json"), "application/json")
        XCTAssertEqual(CoconutSchemeHandler.mimeType(forPath: "favicon.svg"), "image/svg+xml")
        XCTAssertEqual(CoconutSchemeHandler.mimeType(forPath: "font.woff2"), "font/woff2")
        XCTAssertEqual(CoconutSchemeHandler.mimeType(forPath: "blob.bin"), "application/octet-stream")
        // Extension matching is case-insensitive
        XCTAssertEqual(CoconutSchemeHandler.mimeType(forPath: "INDEX.HTML"), "text/html")
    }

    // MARK: - makeResponse

    func testMakeResponseCarriesHeaders() {
        let url = URL(string: "coconut://demo/index.html")!
        let data = Data("<html></html>".utf8)
        let response = CoconutSchemeHandler.makeResponse(for: url, mimeType: "text/html", status: 200, data: data)
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.value(forHTTPHeaderField: "Content-Type"), "text/html")
        XCTAssertEqual(response.value(forHTTPHeaderField: "Content-Length"), String(data.count))
    }
}
