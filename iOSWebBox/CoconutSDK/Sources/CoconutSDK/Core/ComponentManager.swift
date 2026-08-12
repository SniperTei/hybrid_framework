import Foundation
import UIKit

@MainActor
public class ComponentManager {

    public static let shared = ComponentManager()

    private var components: [String: CoconutPlugin] = [:]
    private(set) public var sharedContext: ComponentContext!

    private init() {}

    public func setApplicationContext(_ context: UIApplication) {
        sharedContext = ComponentContext(applicationContext: context)
    }

    public func setHost(_ host: ComponentHost?) {
        sharedContext?.host = host
    }

    public func setSdkVersion(_ version: String) {
        sharedContext?.sdkVersion = version
    }

    public func register(_ component: CoconutPlugin) async throws {
        if components[component.name] != nil {
            Logger.shared.w("ComponentManager", "Component '\(component.name)' already registered")
            return
        }

        for dep in component.dependencies {
            if components[dep] == nil {
                Logger.shared.e("ComponentManager", "Component '\(component.name)' depends on '\(dep)' which is not registered")
                return
            }
        }

        Logger.shared.d("ComponentManager", "Registering: \(component.name) v\(component.version)")

        do {
            try await component.initComponent(context: sharedContext)
            components[component.name] = component
            Logger.shared.i("ComponentManager", "✓ Registered: \(component.name)")
        } catch {
            Logger.shared.e("ComponentManager", "Failed to init: \(component.name)", error)
        }
    }

    public func inject(_ components: [CoconutPlugin]) async {
        for component in components {
            do {
                try await register(component)
            } catch {
                Logger.shared.e("ComponentManager", "Failed to register: \(component.name)", error)
            }
        }
    }

    public func unregister(name: String) async {
        let component = components.removeValue(forKey: name)

        if let component = component {
            await component.cleanup()
            Logger.shared.i("ComponentManager", "✓ Unregistered: \(name)")
        }
    }

    public func getComponent(name: String) -> CoconutPlugin? {
        return components[name]
    }

    public func hasComponent(name: String) -> Bool {
        return components[name] != nil
    }

    public func getRegisteredComponents() -> [String] {
        return Array(components.keys)
    }

    public struct ComponentInfo {
        public let name: String
        public let version: String
        public let description: String
        public let dependencies: [String]
        public let isInitialized: Bool
    }

    public func getComponentInfo(name: String) -> ComponentInfo? {
        guard let component = getComponent(name: name) else { return nil }
        return ComponentInfo(
            name: component.name,
            version: component.version,
            description: component.pluginDescription,
            dependencies: component.dependencies,
            isInitialized: component.isInitialized
        )
    }

    public func getAllComponentsInfo() -> [ComponentInfo] {
        return getRegisteredComponents().compactMap { getComponentInfo(name: $0) }
    }

    /// Snapshot of {componentName: [methods]} for capability detection.
    /// H5 reads this via `__coconutConfig.capabilities` so it can guard feature
    /// calls with coconut.supports(component, fn) instead of try/catching errors.
    public func getCapabilities() -> [String: [String]] {
        var result: [String: [String]] = [:]
        for (name, component) in components {
            result[name] = component.methods
        }
        return result
    }

    public func cleanup() async {
        let allComponents = Array(components.values)
        components.removeAll()

        for component in allComponents {
            await component.cleanup()
        }
        Logger.shared.d("ComponentManager", "All components cleaned up")
    }
}
