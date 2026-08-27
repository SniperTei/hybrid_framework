import XCTest
@testable import CoconutSDK

@MainActor
final class EventEmitterTests: XCTestCase {

    /// Captures every JS script the emitter dispatches.
    /// All access is @MainActor-isolated (emitter + tests both run on main).
    @MainActor
    private final class CapturingExecutor: JSExecutor {
        var scripts: [String] = []
        @discardableResult
        func evaluateJavaScript(_ script: String) async -> Error? {
            scripts.append(script)
            return nil
        }
    }

    private var emitter: EventEmitter!
    private var executor: CapturingExecutor!

    override func setUp() async throws {
        try await super.setUp()
        emitter = EventEmitter()
        executor = CapturingExecutor()
        emitter.jsExecutor = executor
    }

    // MARK: - Core cases

    func test_on_then_emit_deliversToHandler() async {
        emitter.on(topic: "test.echo")
        emitter.emit(topic: "test.echo", data: ["hello": "world"])

        // emit dispatches via Task; yield to let it land.
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(executor.scripts.count, 1)
        let script = executor.scripts[0]
        XCTAssertTrue(script.hasPrefix("window.__coconutEvent('"))
        XCTAssertTrue(script.contains("\"topic\":\"test.echo\""))
        XCTAssertTrue(script.contains("\"hello\":\"world\""))
        XCTAssertFalse(script.contains("subscriptionId"), "payload should not contain subscriptionId")
        XCTAssertTrue(emitter.has(topic: "test.echo"))
        XCTAssertEqual(emitter.count, 1)
    }

    func test_off_blocksSubsequentEmit() async {
        emitter.on(topic: "test.echo")
        emitter.off(topic: "test.echo")
        emitter.emit(topic: "test.echo")

        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(executor.scripts.count, 0)
        XCTAssertEqual(emitter.count, 0)
        XCTAssertFalse(emitter.has(topic: "test.echo"))
    }

    func test_on_sameTopic_overwritesPreviousHandler() async {
        // First on — registers normally
        emitter.on(topic: "test.echo")
        XCTAssertTrue(emitter.has(topic: "test.echo"))
        XCTAssertEqual(emitter.count, 1)

        // Second on same topic — replaces previous (count stays at 1)
        emitter.on(topic: "test.echo")
        XCTAssertEqual(emitter.count, 1, "second on same topic should replace, not append")
    }

    func test_emit_withNoMatchingTopic_isDropped() async {
        emitter.on(topic: "network.change")
        emitter.emit(topic: "app.foreground")  // different topic

        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(executor.scripts.count, 0)
    }

    func test_echo_roundTrip_deliversTestEchoWithPayload() async {
        emitter.on(topic: "test.echo")
        emitter.emit(topic: "test.echo", data: ["hello": "world"])

        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(executor.scripts.count, 1)
        let script = executor.scripts[0]
        XCTAssertTrue(script.contains("\"topic\":\"test.echo\""))
        XCTAssertTrue(script.contains("\"hello\":\"world\""))
    }

    // MARK: - Edge cases

    func test_emit_without_jsExecutor_isSilentlyDropped() async {
        let bareEmitter = EventEmitter()  // no jsExecutor
        bareEmitter.on(topic: "test.echo")
        bareEmitter.emit(topic: "test.echo")
        XCTAssertEqual(bareEmitter.count, 1)
    }

    func test_clearAll_resetsRegistry() async {
        emitter.on(topic: "network.change")
        emitter.on(topic: "test.echo")
        emitter.clearAll()
        emitter.emit(topic: "network.change")
        emitter.emit(topic: "test.echo")

        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(executor.scripts.count, 0)
        XCTAssertEqual(emitter.count, 0)
    }

    func test_on_withEmptyTopic_isRejected() async {
        emitter.on(topic: "")
        emitter.emit(topic: "")

        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(emitter.count, 0)
        XCTAssertEqual(executor.scripts.count, 0)
    }

    func test_off_withUnsubscribedTopic_isSilentNoOp() async {
        // off on a topic that was never subscribed — must not throw / crash
        emitter.off(topic: "never.subscribed")
        XCTAssertEqual(emitter.count, 0)
    }

    func test_escapeJSString_handlesQuotesAndBackslashes() {
        let raw = "it's a \\backslash\nand newline\r"
        let escaped = EventEmitter.escapeJSString(raw)
        XCTAssertTrue(escaped.contains("it\\'s"))
        XCTAssertTrue(escaped.contains("\\\\backslash"))
        XCTAssertTrue(escaped.contains("\\n"))
        XCTAssertTrue(escaped.contains("\\r"))
    }

    // MARK: - emitBypassingSubscription (nav.result delivery path)

    func test_emitBypassingSubscription_dispatchesWithoutRegistration() async {
        // No emitter.on(...) at all — the closing child's page load may have
        // clearAll()'d our registration; delivery must still go through.
        emitter.emitBypassingSubscription(topic: "nav.result", data: ["result": ["orderId": 123]])

        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(executor.scripts.count, 1)
        XCTAssertTrue(executor.scripts[0].contains("\"topic\":\"nav.result\""))
        XCTAssertTrue(executor.scripts[0].contains("orderId"))
    }

    func test_emitBypassingSubscription_afterClearAll_stillDispatches() async {
        emitter.on(topic: "nav.result")
        emitter.clearAll()
        emitter.emitBypassingSubscription(topic: "nav.result", data: ["result": "ok"])

        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(executor.scripts.count, 1)
    }

    func test_emitBypassingSubscription_rejectsEmptyTopic() async {
        emitter.emitBypassingSubscription(topic: "", data: nil)

        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(executor.scripts.count, 0)
    }
}
