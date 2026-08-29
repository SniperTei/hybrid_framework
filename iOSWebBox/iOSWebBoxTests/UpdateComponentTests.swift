import XCTest
import CoconutSDK
@testable import iOSWebBox

/// UpdateComponent iOS 空实现语义（API_CONTRACT.md §4.7 —— 同契约不同实现
/// 首例）：methods 照常声明（supports() = true），但 4 个方法全部业务层
/// 失败（success:false + App Store 2.5.2 说明），不走 bridge error。
@MainActor
final class UpdateComponentTests: XCTestCase {

    private var component: UpdateComponent!

    override func setUp() async throws {
        component = UpdateComponent()
    }

    override func tearDown() async throws {
        component = nil
    }

    func testMeta_nameAndMethods() {
        XCTAssertEqual(component.name, "update")
        XCTAssertEqual(component.methods, ["check", "apply", "rollback", "version"])
    }

    func testAllMethods_businessFailureWithAppStoreReason() async throws {
        for fn in ["check", "apply", "rollback", "version"] {
            let result = try await component.handle(function: fn, params: [:])
            XCTAssertEqual(result["success"] as? Bool, false, "\(fn) should be business failure")
            let message = result["message"] as? String ?? ""
            XCTAssertTrue(message.contains("App Store"), "\(fn) message should cite App Store constraint: \(message)")
            XCTAssertTrue(message.contains("2.5.2"), "\(fn) message should cite guideline 2.5.2: \(message)")
        }
    }

    func testUnknownFunction_throwsUnknownFunctionError() async {
        do {
            _ = try await component.handle(function: "reboot", params: [:])
            XCTFail("expected ComponentException")
        } catch let e as ComponentException {
            XCTAssertEqual(e.code, "200002")
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }
}
