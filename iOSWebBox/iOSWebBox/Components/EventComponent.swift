import Foundation
import CoconutSDK

/// Self-test topic emitted by the demo `echo` method.
public let EVENT_TOPIC_TEST_ECHO = "test.echo"

/**
 * Event Component
 *
 * Exposes subscribe/unsubscribe to H5 (delegating to the shared EventEmitter)
 * and a self-test `echo` method that emits a `test.echo` event after 500ms.
 */
public class EventComponent: BaseComponent {
    override public init() { super.init() }

    override public var name: String { "event" }
    override public var version: String { "1.0.0" }
    override public var pluginDescription: String { "Event subscription component" }

    private var sharedContext: ComponentContext?

    override public func onInit(context: ComponentContext) async {
        sharedContext = context
        Logger.shared.d(name, "Event component initialized")
    }

    override public func handle(function: String, params: [String: Any]?) async throws -> [String: Any] {
        switch function {
        case "subscribe": return try subscribe(params)
        case "unsubscribe": return try unsubscribe(params)
        case "echo": return try echo(params)
        default: try functionNotSupportedError(function)
        }
    }

    /// Register a subscription. Both topic and subscriptionId are H5-supplied.
    private func subscribe(_ params: [String: Any]?) throws -> [String: Any] {
        let topic = getParam(params, "topic")
        let subscriptionId = getParam(params, "subscriptionId")
        if topic.isEmpty || subscriptionId.isEmpty {
            try error(ErrorCode.PARAM_VALIDATION_FAILED, "topic and subscriptionId are required")
        }
        sharedContext?.eventEmitter.subscribe(topic: topic, subscriptionId: subscriptionId)
        return success(["subscriptionId": subscriptionId, "topic": topic])
    }

    private func unsubscribe(_ params: [String: Any]?) throws -> [String: Any] {
        let subscriptionId = getParam(params, "subscriptionId")
        if subscriptionId.isEmpty {
            try error(ErrorCode.PARAM_VALIDATION_FAILED, "subscriptionId is required")
        }
        sharedContext?.eventEmitter.unsubscribe(subscriptionId: subscriptionId)
        return success(["subscriptionId": subscriptionId, "success": true])
    }

    /// Demo: emit `test.echo` with the supplied payload after 500ms.
    private func echo(_ params: [String: Any]?) throws -> [String: Any] {
        let payload = params ?? [:]
        let topic = EVENT_TOPIC_TEST_ECHO
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            self?.sharedContext?.eventEmitter.emit(topic: topic, data: payload)
            Logger.shared.d("event", "echo emitted: \(topic)")
        }
        return success(["scheduled": true, "topic": topic])
    }
}
