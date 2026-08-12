import Foundation

@MainActor
public protocol CoconutPlugin: AnyObject {

    var name: String { get }
    var version: String { get }
    var pluginDescription: String { get }
    var dependencies: [String] { get }
    var methods: [String] { get }
    var isInitialized: Bool { get }

    func initComponent(context: ComponentContext) async throws
    func handle(function: String, params: [String: Any]?) async throws -> [String: Any]
    func cleanup() async
}

public extension CoconutPlugin {
    var pluginDescription: String { "" }
    var dependencies: [String] { [] }
    var methods: [String] { [] }
}
