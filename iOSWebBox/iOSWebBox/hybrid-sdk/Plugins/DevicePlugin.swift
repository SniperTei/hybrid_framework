//
//  DevicePlugin.swift
//  iOSWebBox
//
//  Device information plugin
//

import Foundation
import UIKit
import WebKit

public class DevicePlugin: BasePlugin {

    public override func pluginName() -> String {
        return "device"
    }

    public override func exec(action: String, params: [String: Any], callback: PluginCallback) {
        switch action {
        case "getInfo":
            getInfo(callback: callback)
        default:
            super.exec(action: action, params: params, callback: callback)
        }
    }

    private func getInfo(callback: PluginCallback) {
        let device = UIDevice.current
        let screen = UIScreen.main
        let bundle = Bundle.main

        let info: [String: Any] = [
            "appId": bundle.bundleIdentifier ?? "",
            "appName": bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "",
            "appVersion": bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            "platform": "ios",
            "system": "iOS",
            "systemVersion": device.systemVersion,
            "model": device.model,
            "screenWidth": Int(screen.bounds.size.width),
            "screenHeight": Int(screen.bounds.size.height),
            "screenDensity": screen.scale
        ]

        callback.success(info)
    }
}
