import Foundation

public class SystemComponent: BaseComponent {

    override public var name: String { "system" }
    override public var version: String { "1.0.0" }
    override public var pluginDescription: String { "SDK version and capability introspection" }

    private var componentContext: ComponentContext?

    override public func onInit(context: ComponentContext) async {
        componentContext = context
    }

    override public func handle(function: String, params: [String: Any]?) async -> [String: Any] {
        switch function {
        case "getVersion": return getVersion()
        case "getComponentVersion": return getComponentVersion(params)
        case "getAllComponents": return getAllComponents()
        case "checkCapability": return checkCapability(params)
        default: return functionNotSupportedError(function)
        }
    }

    private func getVersion() -> [String: Any] {
        let version = componentContext?.sdkVersion ?? "1.0.0"
        return success([
            "sdkVersion": version,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ])
    }

    private func getComponentVersion(_ params: [String: Any]?) -> [String: Any] {
        let name = getParam(params, "name")
        if name.isEmpty { return error("900002", "Parameter 'name' is required") }

        guard let info = ComponentManager.shared.getComponentInfo(name: name) else {
            return error("900001", "Component not found: \(name)")
        }

        return success([
            "name": info.name,
            "version": info.version,
            "description": info.description,
            "initialized": info.isInitialized
        ])
    }

    private func getAllComponents() -> [String: Any] {
        let infos = ComponentManager.shared.getAllComponentsInfo()
        let list = infos.map { info -> [String: Any] in
            return [
                "name": info.name,
                "version": info.version,
                "description": info.description,
                "initialized": info.isInitialized
            ]
        }
        return success(["count": list.count, "components": list])
    }

    private func checkCapability(_ params: [String: Any]?) -> [String: Any] {
        let method = getParam(params, "method")
        if method.isEmpty { return error("900002", "Parameter 'method' is required") }

        let componentName = method.components(separatedBy: ".").first ?? ""
        let component = ComponentManager.shared.getComponent(name: componentName)

        return success([
            "method": method,
            "available": component != nil,
            "componentRegistered": component != nil,
            "componentInitialized": component?.isInitialized ?? false
        ])
    }

    override public func onCleanup() async {
        componentContext = nil
    }
}
