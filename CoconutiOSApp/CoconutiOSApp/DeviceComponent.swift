//
//  DeviceComponent.swift
//  CoconutiOSApp
//
//  消费者自定义组件示例：设备信息（对齐 API_CONTRACT.md §4.1 的 device 字段集）。
//  methods 数组必须与 handle() 的 switch 分支一致 —— coconut.supports() 据此
//  向 H5 透出能力。
//

import Foundation
import UIKit
import CoconutSDK

class DeviceComponent: BaseComponent {

    override init() { super.init() }

    override var name: String { "device" }
    override var version: String { "1.0.0" }
    override var pluginDescription: String { "Minimal device info component (consumer app sample)" }
    override var methods: [String] { ["getInfo", "getSystemInfo", "getAppInfo"] }

    override func handle(function: String, params: [String: Any]?) async throws -> [String: Any] {
        switch function {
        case "getInfo": return getInfo()
        case "getSystemInfo": return getSystemInfo()
        case "getAppInfo": return getAppInfo()
        default: try functionNotSupportedError(function)
        }
    }

    private func getInfo() -> [String: Any] {
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
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
        #if DEBUG
        let debug = true
        #else
        let debug = false
        #endif
        return success([
            "appName": "CoconutiOSApp",
            "packageName": bundleId,
            "version": version,
            "buildNumber": build,
            "debug": debug
        ])
    }
}
