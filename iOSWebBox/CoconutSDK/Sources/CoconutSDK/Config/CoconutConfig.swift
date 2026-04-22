import Foundation
import UIKit

public class CoconutConfig {

    public static let shared = CoconutConfig()

    public var debugMode = false
    public var defaultTimeout = 15000
    public var sdkVersion = "2.0.0"
    public var environment: Environment = .dev
    public var enableBridgeToken = true
    public var enableRequestSigning = false
    public var bridgeSharedSecret = ""
    public var allowedDomains: [String] = []
    public var maxBridgeParamsSize = 1024 * 1024
    public var rateLimitPerMethod = 100
    public var rateLimitWindowMs: Int64 = 60_000
    public var signingTimestampToleranceMs: Int64 = 300_000

    private init() {}
}

public class CoconutSDK {

    public static private(set) var isInitialized = false

    public static func initialize() async {
        guard !isInitialized else { return }

        let config = CoconutConfig.shared
        Logger.shared.setDebugMode(config.debugMode)

        // Apply security settings
        BridgeTokenManager.shared.enabled = config.enableBridgeToken
        BridgeTokenManager.shared.generateToken()

        RequestSignatureValidator.shared.enabled = config.enableRequestSigning
        RequestSignatureValidator.shared.sharedSecret = config.bridgeSharedSecret
        RequestSignatureValidator.shared.timestampToleranceMs = config.signingTimestampToleranceMs

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
