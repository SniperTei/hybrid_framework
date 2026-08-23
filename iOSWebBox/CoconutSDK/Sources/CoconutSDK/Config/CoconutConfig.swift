import Foundation
import UIKit

@MainActor
public class CoconutConfig {

    public static let shared = CoconutConfig()

    public var debugMode = false
    public var defaultTimeout = 15000
    public var sdkVersion = "3.4.0"
    public var environment: Environment = .dev
    public var enableBridgeToken = true
    public var allowedDomains: [String] = []
    public var maxBridgeParamsSize = 1024 * 1024
    public var rateLimitPerMethod = 100
    public var rateLimitWindowMs: Int64 = 60_000

    private init() {}
}

@MainActor
public class CoconutSDK {

    public static private(set) var isInitialized = false

    public static func initialize() async {
        guard !isInitialized else { return }

        let config = CoconutConfig.shared
        Logger.shared.setDebugMode(config.debugMode)

        // Apply security settings
        BridgeTokenManager.shared.enabled = config.enableBridgeToken
        BridgeTokenManager.shared.generateToken()

        ComponentManager.shared.setApplicationContext(UIApplication.shared)
        ComponentManager.shared.setSdkVersion(config.sdkVersion)

        // NOTE: components are no longer auto-registered. The host app must call
        // registerComponents(...) after initialize() so it controls exactly which
        // components are active. This mirrors Android's WebBoxApplication pattern.
        isInitialized = true
        Logger.shared.i("CoconutSDK", "✓ SDK initialized (v\(config.sdkVersion), env: \(config.environment.displayName))")
    }

    /// Register multiple components explicitly.
    /// Mirrors `CoconutSDK.registerComponents(vararg BaseComponent)` on Android.
    public static func registerComponents(_ components: [CoconutPlugin]) async {
        guard isInitialized else {
            Logger.shared.e("CoconutSDK", "Cannot register components: SDK not initialized. Call CoconutSDK.initialize() first.")
            return
        }
        await ComponentManager.shared.inject(components)
    }

    /// Register a single component.
    public static func registerComponent(_ component: CoconutPlugin) async {
        guard isInitialized else {
            Logger.shared.e("CoconutSDK", "Cannot register component: SDK not initialized. Call CoconutSDK.initialize() first.")
            return
        }
        try? await ComponentManager.shared.register(component)
    }

    public static func configure(_ block: (CoconutConfig) -> Void) {
        block(CoconutConfig.shared)
    }

    public static func getConfig() -> CoconutConfig {
        return CoconutConfig.shared
    }
}
