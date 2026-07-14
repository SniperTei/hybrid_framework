import Foundation
import UIKit
@testable import CoconutSDK

/// In-process CoconutPlugin stub for unit tests. Tracks lifecycle calls and
/// supports configurable handle results / thrown errors.
@MainActor
final class MockPlugin: CoconutPlugin {

    let name: String
    let version: String = "1.0.0"
    let pluginDescription: String = "mock"
    let dependencies: [String]

    private(set) var isInitialized = false
    private(set) var initCallCount = 0
    private(set) var cleanupCallCount = 0
    private(set) var lastHandledFunction: String?
    private(set) var lastHandledParams: [String: Any]?

    /// Result returned from `handle` when `throwOnHandle` is nil.
    var handleResult: [String: Any]
    /// When non-nil, `handle` throws this instead of returning `handleResult`.
    var throwOnHandle: ComponentException?

    /// When true, `initComponent` throws (simulating init failure).
    var failInit: Bool = false

    init(name: String,
         dependencies: [String] = [],
         handleResult: [String: Any] = ["ok": true]) {
        self.name = name
        self.dependencies = dependencies
        self.handleResult = handleResult
    }

    func initComponent(context: ComponentContext) async throws {
        initCallCount += 1
        if failInit {
            throw ComponentException(code: "200008", message: "Mock init failure")
        }
        isInitialized = true
    }

    func handle(function: String, params: [String: Any]?) async throws -> [String: Any] {
        lastHandledFunction = function
        lastHandledParams = params
        if let e = throwOnHandle {
            throw e
        }
        return handleResult
    }

    func cleanup() async {
        cleanupCallCount += 1
        isInitialized = false
    }

    /// Test-only hook to flip initialization state without re-running init.
    func setInitializedForTesting(_ value: Bool) {
        isInitialized = value
    }
}
