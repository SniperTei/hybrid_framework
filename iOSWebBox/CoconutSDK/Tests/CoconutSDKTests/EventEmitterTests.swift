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

    func test_subscribe_then_emit_deliversToSubscriber() async {
        emitter.subscribe(topic: "test.echo", subscriptionId: "sub_1")
        emitter.emit(topic: "test.echo", data: ["hello": "world"])

        // emit dispatches via Task; yield to let it land.
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(executor.scripts.count, 1)
        let script = executor.scripts[0]
        XCTAssertTrue(script.hasPrefix("window.__coconutEvent('"))
        XCTAssertTrue(script.contains("\"topic\":\"test.echo\""))
        XCTAssertTrue(script.contains("\"subscriptionId\":\"sub_1\""))
        XCTAssertTrue(script.contains("\"hello\":\"world\""))
        XCTAssertEqual(emitter.count, 1)
    }

    func test_unsubscribe_blocksSubsequentEmit() async {
        emitter.subscribe(topic: "test.echo", subscriptionId: "sub_1")
        emitter.unsubscribe(subscriptionId: "sub_1")
        emitter.emit(topic: "test.echo")

        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(executor.scripts.count, 0)
        XCTAssertEqual(emitter.count, 0)
    }

    func test_multiple_subscribers_for_same_topic_allReceive() async {
        emitter.subscribe(topic: "network.change", subscriptionId: "sub_a")
        emitter.subscribe(topic: "network.change", subscriptionId: "sub_b")
        emitter.emit(topic: "network.change", data: 42)

        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(executor.scripts.count, 2)
        let ids = executor.scripts.compactMap { Self.extractSubscriptionId(from: $0) }
        XCTAssertEqual(Set(ids), ["sub_a", "sub_b"])
        for script in executor.scripts {
            XCTAssertTrue(script.contains("\"data\":42"))
        }
    }

    func test_emit_withNoMatchingTopic_isDropped() async {
        emitter.subscribe(topic: "network.change", subscriptionId: "sub_a")
        emitter.emit(topic: "app.foreground")  // different topic

        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(executor.scripts.count, 0)
    }

    func test_echo_roundTrip_deliversTestEchoWithPayload() async {
        emitter.subscribe(topic: "test.echo", subscriptionId: "sub_echo")
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
        bareEmitter.subscribe(topic: "test.echo", subscriptionId: "sub_1")
        bareEmitter.emit(topic: "test.echo")
        XCTAssertEqual(bareEmitter.count, 1)
    }

    func test_clearAll_resetsRegistry() async {
        emitter.subscribe(topic: "network.change", subscriptionId: "sub_a")
        emitter.subscribe(topic: "test.echo", subscriptionId: "sub_b")
        emitter.clearAll()
        emitter.emit(topic: "network.change")
        emitter.emit(topic: "test.echo")

        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(executor.scripts.count, 0)
        XCTAssertEqual(emitter.count, 0)
    }

    func test_subscribe_withEmptyArgs_isRejected() async {
        emitter.subscribe(topic: "", subscriptionId: "sub_1")
        emitter.subscribe(topic: "test.echo", subscriptionId: "")
        emitter.emit(topic: "")

        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(emitter.count, 0)
        XCTAssertEqual(executor.scripts.count, 0)
    }

    func test_escapeJSString_handlesQuotesAndBackslashes() {
        let raw = "it's a \\backslash\nand newline\r"
        let escaped = EventEmitter.escapeJSString(raw)
        XCTAssertTrue(escaped.contains("it\\'s"))
        XCTAssertTrue(escaped.contains("\\\\backslash"))
        XCTAssertTrue(escaped.contains("\\n"))
        XCTAssertTrue(escaped.contains("\\r"))
    }

    // MARK: - Helpers

    private static func extractSubscriptionId(from script: String) -> String? {
        let marker = "\"subscriptionId\":\""
        guard let range = script.range(of: marker) else { return nil }
        let start = range.upperBound
        guard let end = script[start...].firstIndex(of: "\"") else { return nil }
        return String(script[start..<end])
    }
}
