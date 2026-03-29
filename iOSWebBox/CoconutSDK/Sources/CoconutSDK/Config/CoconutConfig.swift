import Foundation
import UIKit

public class CoconutConfig {

    public static let shared = CoconutConfig()

    public var debugMode = false
    public var defaultTimeout = 15000
    public var sdkVersion = "1.0.0"
    public var environment: Environment = .dev
    public var enableBridgeToken = false
    public var enableRequestSigning = false
    public var bridgeSharedSecret = ""
    public var allowedDomains: [String] = []
    public var maxBridgeParamsSize = 1024 * 1024

    private init() {}
}

public class CoconutSDK {

    public static private(set) var isInitialized = false

    public static func initialize() async {
        guard !isInitialized else { return }

        let config = CoconutConfig.shared
        Logger.shared.setDebugMode(config.debugMode)

        ComponentManager.shared.setApplicationContext(UIApplication.shared)
        ComponentManager.shared.setSdkVersion(config.sdkVersion)

        await ComponentManager.shared.autoRegister()

        isInitialized = true
        Logger.shared.i("CoconutSDK", "✓ SDK initialized (v\(config.sdkVersion), env: \(config.environment.displayName))")
    }

    public static func configure(_ block: (CoconutConfig) -> Void) {
        block(CoconutConfig.shared)
    }

    public static func getConfig() -> CoconutConfig {
        return CoconutConfig.shared
    }
}
