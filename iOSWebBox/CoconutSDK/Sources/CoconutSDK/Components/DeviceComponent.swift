import Foundation
import UIKit

public class DeviceComponent: BaseComponent {

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
        return success([
            "manufacturer": "Apple",
            "brand": "Apple",
            "model": device.model,
            "device": device.identifierForVendor?.uuidString ?? "unknown",
            "product": device.systemName,
            "platform": "iOS",
            "screenWidth": UIScreen.main.bounds.width,
            "screenHeight": UIScreen.main.bounds.height,
            "screenScale": UIScreen.main.scale
        ])
    }

    private func getSystemInfo() -> [String: Any] {
        let device = UIDevice.current
        return success([
            "iOSVersion": device.systemVersion,
            "systemName": device.systemName,
            "model": device.model,
            "localizedModel": device.localizedModel,
            "userInterfaceIdiom": "\(device.userInterfaceIdiom)"
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
        var allData: [String: Any] = [:]
        let deviceInfo = getDeviceInfo()
        let systemInfo = getSystemInfo()
        let appInfo = getAppInfo()
        allData.merge(deviceInfo) { $1 }
        allData["system"] = systemInfo
        allData["app"] = appInfo
        return success(allData)
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
