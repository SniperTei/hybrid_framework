import Foundation
import UIKit
import AVFoundation
import Photos
import Contacts
import CoreLocation
import CoconutSDK

public class PermissionComponent: BaseComponent {
    public init() { super.init() }

    override public var name: String { "permission" }
    override public var version: String { "1.0.0" }
    override public var pluginDescription: String { "Permission management component" }

    private var componentContext: ComponentContext?
    private var locationManager: CLLocationManager?

    override public func onInit(context: ComponentContext) async {
        componentContext = context
    }

    override public func handle(function: String, params: [String: Any]?) async throws -> [String: Any] {
        switch function {
        case "check": return try checkPermission(params)
        case "request": return try await requestPermission(params)
        case "openSettings": return await openSettings()
        default: try functionNotSupportedError(function)
        }
    }

    private func checkPermission(_ params: [String: Any]?) throws -> [String: Any] {
        let permission = getParam(params, "permission")
        if permission.isEmpty { try error("200007", "Parameter 'permission' is required") }

        let status = getPermissionStatus(permission)
        return success(["permission": permission, "status": status])
    }

    @MainActor
    private func requestPermission(_ params: [String: Any]?) async throws -> [String: Any] {
        let permission = getParam(params, "permission")
        if permission.isEmpty { try error("200007", "Parameter 'permission' is required") }

        let status: String
        switch permission {
        case "camera":
            status = await requestCameraPermission()
        case "photos":
            status = await requestPhotosPermission()
        case "microphone":
            status = await requestMicrophonePermission()
        case "contacts":
            status = await requestContactsPermission()
        case "location":
            status = await requestLocationPermission()
        default:
            return success(["permission": permission, "status": "unsupported"])
        }

        return success(["permission": permission, "status": status])
    }

    @MainActor
    private func openSettings() -> [String: Any] {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return success(["opened": false])
        }
        UIApplication.shared.open(url)
        return success(["opened": true])
    }

    private func getPermissionStatus(_ permission: String) -> String {
        switch permission {
        case "camera":
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            return avStatusToString(status)
        case "photos":
            let status: PHAuthorizationStatus
            if #available(iOS 14, *) {
                status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            } else {
                status = PHPhotoLibrary.authorizationStatus()
            }
            return phStatusToString(status)
        case "microphone":
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            return avStatusToString(status)
        case "contacts":
            let status = CNContactStore.authorizationStatus(for: .contacts)
            return cnStatusToString(status)
        case "location":
            guard let manager = locationManager else { return "notDetermined" }
            let status = CLLocationManager.authorizationStatus()
            return clStatusToString(status)
        default:
            return "unsupported"
        }
    }

    private func requestCameraPermission() async -> String {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted ? "authorized" : "denied")
            }
        }
    }

    private func requestPhotosPermission() async -> String {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: self.phStatusToString(status))
            }
        }
    }

    private func requestMicrophonePermission() async -> String {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted ? "authorized" : "denied")
            }
        }
    }

    private func requestContactsPermission() async -> String {
        await withCheckedContinuation { continuation in
            let store = CNContactStore()
            store.requestAccess(for: .contacts) { granted, _ in
                continuation.resume(returning: granted ? "authorized" : "denied")
            }
        }
    }

    private func requestLocationPermission() async -> String {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let manager = CLLocationManager()
                self.locationManager = manager
                manager.requestWhenInUseAuthorization()
                // Location permission is async via delegate, return current status
                let status = CLLocationManager.authorizationStatus()
                continuation.resume(returning: self.clStatusToString(status))
            }
        }
    }

    private func avStatusToString(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "notDetermined"
        @unknown default: return "unknown"
        }
    }

    private func phStatusToString(_ status: PHAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "notDetermined"
        case .limited: return "limited"
        @unknown default: return "unknown"
        }
    }

    private func cnStatusToString(_ status: CNAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "notDetermined"
        @unknown default: return "unknown"
        }
    }

    private func clStatusToString(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .authorizedAlways: return "authorized"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "notDetermined"
        @unknown default: return "unknown"
        }
    }

    override public func onCleanup() async {
        componentContext = nil
        locationManager = nil
    }
}
