import Foundation
import CoconutSDK

/**
 * MyTest Component
 *
 * A minimal scaffold component for development/debugging.
 * Useful for verifying that the Bridge → Component routing works end-to-end,
 * and as a copy-paste starting point when adding a new real component.
 *
 * Functions:
 *   - ping: {} -> { pong: true, timestamp }
 *       Health-check; returns immediately.
 *   - echo: { message } -> { message }
 *       Echoes back the provided message (validates params round-trip).
 *   - add: { a, b } -> { sum }
 *       Adds two integers (demonstrates getIntParam + numeric result).
 */
public class MyTestComponent: BaseComponent {
    override public init() { super.init() }

    override public var name: String { "mytest" }
    override public var version: String { "1.0.0" }
    override public var pluginDescription: String { "Test scaffold component for development" }

    override public func handle(function: String, params: [String: Any]?) async throws -> [String: Any] {
        switch function {
        case "ping": return ping()
        case "echo": return try echo(params)
        case "add":  return add(params)
        default: try functionNotSupportedError(function)
        }
    }

    private func ping() -> [String: Any] {
        return success([
            "pong": true,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ])
    }

    private func echo(_ params: [String: Any]?) throws -> [String: Any] {
        let message = getParam(params, "message")
        if message.isEmpty { try error(ErrorCode.PARAM_VALIDATION_FAILED, "Parameter 'message' is required") }
        return success(["message": message])
    }

    private func add(_ params: [String: Any]?) -> [String: Any] {
        let a = getIntParam(params, "a", 0)
        let b = getIntParam(params, "b", 0)
        return success(["sum": a + b])
    }
}
