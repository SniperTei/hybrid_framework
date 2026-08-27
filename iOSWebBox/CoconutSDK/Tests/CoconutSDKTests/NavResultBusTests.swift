import XCTest
@testable import CoconutSDK

/// NavResultBus single-slot semantics — post/consume/overwrite/clear.
final class NavResultBusTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Drain any pending leftover from other tests.
        _ = NavResultBus.consume()
    }

    func testConsumeReturnsPostedValueThenEmpties() {
        NavResultBus.post(#"{"orderId":123}"#)
        XCTAssertEqual(#"{"orderId":123}"#, NavResultBus.consume())
        XCTAssertNil(NavResultBus.consume(), "single slot: second consume must be nil")
    }

    func testPostOverwritesPreviousPending() {
        NavResultBus.post("first")
        NavResultBus.post("second")
        XCTAssertEqual("second", NavResultBus.consume())
    }

    func testConsumeOnEmptySlotIsNil() {
        XCTAssertNil(NavResultBus.consume())
    }
}
