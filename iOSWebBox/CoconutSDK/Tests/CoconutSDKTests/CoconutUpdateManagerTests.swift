import XCTest
@testable import CoconutSDK

final class CoconutUpdateManagerTests: XCTestCase {

    private var manager: CoconutUpdateManager!

    override func setUp() {
        super.setUp()
        manager = CoconutUpdateManager.shared
    }

    // MARK: - compareVersions

    func testCompareVersionsEqual() {
        XCTAssertEqual(CoconutUpdateManager.compareVersions("1.0.0", "1.0.0"), 0)
    }

    func testCompareVersionsPatchAndMajor() {
        XCTAssertGreaterThan(CoconutUpdateManager.compareVersions("1.0.1", "1.0.0"), 0)
        XCTAssertLessThan(CoconutUpdateManager.compareVersions("0.9.9", "1.0.0"), 0)
        XCTAssertGreaterThan(CoconutUpdateManager.compareVersions("2.0.0", "1.99.99"), 0)
    }

    func testCompareVersionsMissingSegmentsAndGarbage() {
        XCTAssertEqual(CoconutUpdateManager.compareVersions("1.2", "1.2.0"), 0)
        XCTAssertEqual(CoconutUpdateManager.compareVersions("x.y.z", "0.0.0"), 0)
    }

    // MARK: - isSafePackagePath

    func testSafePathsAccepted() {
        XCTAssertTrue(CoconutUpdateManager.isSafePackagePath("index.html"))
        XCTAssertTrue(CoconutUpdateManager.isSafePackagePath("js/app.js"))
        XCTAssertTrue(CoconutUpdateManager.isSafePackagePath("assets/fonts/v1/font.woff2"))
    }

    func testUnsafePathsRejected() {
        XCTAssertFalse(CoconutUpdateManager.isSafePackagePath(""))
        XCTAssertFalse(CoconutUpdateManager.isSafePackagePath("/etc/passwd"))
        XCTAssertFalse(CoconutUpdateManager.isSafePackagePath("../escape.js"))
        XCTAssertFalse(CoconutUpdateManager.isSafePackagePath("a/../../escape.js"))
        XCTAssertFalse(CoconutUpdateManager.isSafePackagePath("a\\b.js"))
        XCTAssertFalse(CoconutUpdateManager.isSafePackagePath("a//b.js"))
        XCTAssertFalse(CoconutUpdateManager.isSafePackagePath("."))
    }

    // MARK: - md5Hex

    func testMd5KnownVectors() {
        XCTAssertEqual(CoconutUpdateManager.md5Hex(Data("hello".utf8)), "5d41402abc4b2a76b9719d911017c592")
        XCTAssertEqual(CoconutUpdateManager.md5Hex(Data()), "d41d8cd98f00b204e9800998ecf8427e")
    }

    // MARK: - decideUpdate

    func testDecideUpdateTruthTable() {
        XCTAssertTrue(CoconutUpdateManager.decideUpdate(sandboxVersion: "1.0.0", bundledVersion: "1.0.0", remoteVersion: "1.0.1"))
        XCTAssertFalse(CoconutUpdateManager.decideUpdate(sandboxVersion: nil, bundledVersion: "1.0.1", remoteVersion: "1.0.1"))
        XCTAssertFalse(CoconutUpdateManager.decideUpdate(sandboxVersion: "1.2.0", bundledVersion: "1.0.0", remoteVersion: "1.1.0"))
        XCTAssertTrue(CoconutUpdateManager.decideUpdate(sandboxVersion: nil, bundledVersion: nil, remoteVersion: "0.0.1"))
    }

    // MARK: - validateManifest

    private func makeManifest(files: [String], hashes: [String: String] = [:]) -> CoconutUpdateManager.RemoteManifest {
        CoconutUpdateManager.RemoteManifest(moduleId: "demo", version: "1.0.1", files: files, fileHashes: hashes)
    }

    func testValidateManifestOk() {
        let m = makeManifest(files: ["index.html", "js/app.js"],
                             hashes: ["index.html": "aa", "js/app.js": "bb"])
        XCTAssertNil(CoconutUpdateManager.validateManifest(m))
    }

    func testValidateManifestNoFilesRejected() {
        XCTAssertEqual(CoconutUpdateManager.validateManifest(makeManifest(files: [])), "manifest has no files")
    }

    func testValidateManifestMissingHashFailClosed() {
        let m = makeManifest(files: ["index.html"])
        XCTAssertEqual(CoconutUpdateManager.validateManifest(m), "missing fileHashes entry: index.html")
    }

    func testValidateManifestUnsafePathRejected() {
        let m = makeManifest(files: ["../evil.js"], hashes: ["../evil.js": "aa"])
        XCTAssertEqual(CoconutUpdateManager.validateManifest(m), "unsafe package path: ../evil.js")
    }

    // MARK: - RemoteManifest decoding (tolerant)

    func testRemoteManifestDecodesServerJson() throws {
        let json = """
        {"moduleId":"demo","version":"1.0.1","entry":"index.html",
         "files":["index.html","assets/index.js"],
         "md5":"pkg","fileHashes":{"index.html":"aa","assets/index.js":"bb"},
         "extraField":123}
        """
        let m = try JSONDecoder().decode(CoconutUpdateManager.RemoteManifest.self, from: Data(json.utf8))
        XCTAssertEqual(m.moduleId, "demo")
        XCTAssertEqual(m.files, ["index.html", "assets/index.js"])
        XCTAssertEqual(m.fileHashes["assets/index.js"], "bb")
    }

    // MARK: - swapStaged / rollback (temp sandbox)

    private func makeTempSandbox() -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("coconut-update-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    func testSwapStagedReplacesModuleDir() throws {
        let root = makeTempSandbox()
        defer { try? FileManager.default.removeItem(at: root) }
        let moduleDir = root.appendingPathComponent("demo", isDirectory: true)
        try FileManager.default.createDirectory(at: moduleDir, withIntermediateDirectories: true)
        try Data("OLD".utf8).write(to: moduleDir.appendingPathComponent("index.html"))
        let staging = root.appendingPathComponent(".staging_demo", isDirectory: true)
        try FileManager.default.createDirectory(
            at: staging.appendingPathComponent("js", isDirectory: true), withIntermediateDirectories: true)
        try Data("NEW".utf8).write(to: staging.appendingPathComponent("index.html"))
        try Data("console.log(1)".utf8).write(to: staging.appendingPathComponent("js/app.js"))

        try CoconutUpdateManager.swapStaged(sandboxRoot: root, moduleId: "demo")

        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("demo/index.html"), encoding: .utf8), "NEW")
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("demo/js/app.js"), encoding: .utf8), "console.log(1)")
        XCTAssertFalse(FileManager.default.fileExists(atPath: staging.path))
    }

    func testJoinUrlHandlesTrailingSlash() {
        XCTAssertEqual(CoconutUpdateManager.joinUrl("http://h:8000", "a/b.js"), "http://h:8000/a/b.js")
        XCTAssertEqual(CoconutUpdateManager.joinUrl("http://h:8000/", "a/b.js"), "http://h:8000/a/b.js")
    }

    // MARK: - checkUpdate failure path

    func testCheckUpdateUnreachableReportsError() async {
        // Port 1 → connection refused, deterministic without a server
        let result = await manager.checkUpdate(moduleId: "demo", manifestUrl: "http://127.0.0.1:1/manifest.json")
        XCTAssertFalse(result.available)
        XCTAssertNotNil(result.error)
    }
}
