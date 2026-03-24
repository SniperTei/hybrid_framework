import Foundation
import UIKit
import SystemConfiguration

/// 设备信息插件
public class DevicePlugin: BasePlugin {
    public override func pluginName() -> String {
        return "device"
    }

    public override func exec(action: String, params: [String: Any], callback: PluginCallback) {
        switch action {
        case "getInfo":
            getInfo(callback: callback)
        default:
            callback.error(code: "UNKNOWN_ACTION", message: "Unknown action: \(action)")
        }
    }

    /// 获取设备信息
    private func getInfo(callback: PluginCallback) {
        let device = UIDevice.current
        let screen = UIScreen.main
        let bundle = Bundle.main

        let info: [String: Any] = [
            "appId": bundle.bundleIdentifier ?? "",
            "appName": bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "",
            "appVersion": bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            "platform": "ios",
            "system": "iOS",
            "systemVersion": device.systemVersion,
            "model": device.model,
            "deviceName": device.name,
            "screenWidth": Int(screen.bounds.size.width),
            "screenHeight": Int(screen.bounds.size.height),
            "screenScale": screen.scale,
            "screenDensity": Int(screen.scale * 160), // 转换为Android的dpi标准
            "batteryLevel": getBatteryLevel(),
            "batteryState": getBatteryState(),
            "networkStatus": getNetworkStatus()
        ]

        callback.success(info)
    }

    /// 获取电池电量
    private func getBatteryLevel() -> Int {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        return level < 0 ? 0 : Int(level * 100)
    }

    /// 获取电池状态
    private func getBatteryState() -> String {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let state = UIDevice.current.batteryState

        switch state {
        case .charging:
            return "charging"
        case .full:
            return "full"
        case .unplugged:
            return "unplugged"
        default:
            return "unknown"
        }
    }

    /// 获取网络状态
    private func getNetworkStatus() -> String {
        // 简化实现,实际可以使用Reachability库
        return "unknown"
    }
}
