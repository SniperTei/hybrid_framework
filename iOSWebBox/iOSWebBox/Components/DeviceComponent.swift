import Foundation
import UIKit
import CoconutSDK

public class DeviceComponent: BaseComponent {
    override public init() { super.init() }

    override public var name: String { "device" }
    override public var version: String { "1.0.0" }
    override public var pluginDescription: String { "Device and system information component" }

    override public func handle(function: String, params: [String: Any]?) async throws -> [String: Any] {
        switch function {
        case "getInfo": return getDeviceInfo()
        case "getSystemInfo": return getSystemInfo()
        case "getAppInfo": return getAppInfo()
        case "getAll": return getAllInfo()
        default: try functionNotSupportedError(function)
        }
    }

    private func getDeviceInfo() -> [String: Any] {
        let device = UIDevice.current
        let screen = UIScreen.main
        return success([
            "manufacturer": "Apple",
            "brand": "Apple",
            "model": device.localizedModel,
            "osName": "iOS",
            "osVersion": device.systemVersion,
            "platform": "ios",
            "screenWidth": screen.bounds.width,
            "screenHeight": screen.bounds.height,
            "screenScale": screen.scale
        ])
    }

    private func getSystemInfo() -> [String: Any] {
        let device = UIDevice.current
        return success([
            "osName": "iOS",
            "osVersion": device.systemVersion,
            "sdkVersion": device.systemVersion,
            "model": device.localizedModel,
            "localizedModel": device.localizedModel
        ])
    }

    private func getAppInfo() -> [String: Any] {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
        return success([
            "appName": "CoconutSDK",
            "packageName": bundleId,
            "version": version,
            "buildNumber": build,
            "debug": ConfigHelper.isDebugMode
        ])
    }

    private func getAllInfo() -> [String: Any] {
        let device = getDeviceInfo()
        let system = getSystemInfo()
        let app = getAppInfo()
        return success([
            "device": device,
            "system": system,
            "app": app
        ])
    }
}

private enum ConfigHelper {
    static var isDebugMode: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
