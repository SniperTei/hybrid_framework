//
//  VideoPlugin.swift
//  iOSWebBox
//
//  Video recording plugin
//

import Foundation
import UIKit
import AVFoundation
import MobileCoreServices

public class VideoPlugin: BasePlugin {
    private var currentCallback: PluginCallback?

    public override func pluginName() -> String {
        return "video"
    }

    public override func exec(action: String, params: [String: Any], callback: PluginCallback) {
        switch action {
        case "record":
            record(params: params, callback: callback)
        case "isAvailable":
            isAvailable(callback: callback)
        default:
            super.exec(action: action, params: params, callback: callback)
        }
    }

    private func isAvailable(callback: PluginCallback) {
        let available = UIImagePickerController.isSourceTypeAvailable(.camera) &&
                       UIImagePickerController.availableMediaTypes(for: .camera)?.contains(UTType.movie.identifier) == true
        callback.success(available)
    }

    private func record(params: [String: Any], callback: PluginCallback) {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            callback.error("UNAVAILABLE", message: "Camera not available")
            return
        }

        let availableTypes = UIImagePickerController.availableMediaTypes(for: .camera) ?? []
        guard availableTypes.contains(UTType.movie.identifier) else {
            callback.error("UNAVAILABLE", message: "Video recording not available")
            return
        }

        // Check camera and microphone permissions
        checkPermissions { [weak self] granted in
            if granted {
                self?.presentVideoCamera(params: params, callback: callback)
            } else {
                callback.error("PERMISSION_DENIED", message: "Camera or microphone permission denied")
            }
        }
    }

    private func checkPermissions(completion: @escaping (Bool) -> Void) {
        let videoAuth = AVCaptureDevice.authorizationStatus(for: .video)
        let audioAuth = AVCaptureDevice.authorizationStatus(for: .audio)

        let videoNeeded = videoAuth == .notDetermined
        let audioNeeded = audioAuth == .notDetermined

        if videoNeeded || audioNeeded {
            var granted = true

            if videoNeeded {
                AVCaptureDevice.requestAccess(for: .video) { result in
                    if !result { granted = false }

                    if audioNeeded {
                        AVCaptureDevice.requestAccess(for: .audio) { result in
                            completion(granted && result)
                        }
                    } else {
                        completion(granted)
                    }
                }
            } else if audioNeeded {
                AVCaptureDevice.requestAccess(for: .audio) { result in
                    completion(granted && result)
                }
            }
        } else {
            completion(videoAuth == .authorized && audioAuth == .authorized)
        }
    }

    private func presentVideoCamera(params: [String: Any], callback: PluginCallback) {
        guard let context = pluginContext else {
            callback.error("ERROR", message: "Invalid context")
            return
        }

        currentCallback = callback

        let pickerDelegate = VideoPickerDelegate { [weak self] url in
            guard let self = self,
                  let callback = self.currentCallback else { return }

            if let url = url {
                self.saveVideo(url: url, callback: callback)
            } else {
                callback.error("CANCELLED", message: "User cancelled")
            }
            self.currentCallback = nil
        }

        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = [UTType.movie.identifier]
        picker.cameraCaptureMode = .video
        picker.videoQuality = .typeHigh
        picker.videoMaximumDuration = TimeInterval(optInt(params, "maxDuration") ?? 60)
        picker.delegate = pickerDelegate

        // Store delegate to prevent deallocation
        objc_setAssociatedObject(picker, "delegate", pickerDelegate, .OBJC_ASSOCIATION_RETAIN)

        context.viewController.present(picker, animated: true)
    }

    private func saveVideo(url: URL, callback: PluginCallback) {
        let filename = "video_\(Int(Date().timeIntervalSince1970)).mov"
        let destPath = (NSTemporaryDirectory() as NSString).appendingPathComponent(filename)

        do {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: destPath) {
                try fileManager.removeItem(atPath: destPath)
            }
            try fileManager.copyItem(atPath: url.path, toPath: destPath)

            let attributes = try fileManager.attributesOfItem(atPath: destPath)
            let fileSize = attributes[.size] as? UInt64 ?? 0

            callback.success([
                "path": destPath,
                "filename": filename,
                "size": fileSize
            ])
        } catch {
            callback.error("ERROR", message: "Failed to save video: \(error.localizedDescription)")
        }
    }
}

// MARK: - Video Picker Delegate
private class VideoPickerDelegate: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let completionHandler: (URL?) -> Void

    init(completionHandler: @escaping (URL?) -> Void) {
        self.completionHandler = completionHandler
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true) {
            guard let mediaType = info[.mediaType] as? String,
                  mediaType == UTType.movie.identifier,
                  let url = info[.mediaURL] as? URL else {
                self.completionHandler(nil)
                return
            }
            self.completionHandler(url)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) {
            self.completionHandler(nil)
        }
    }
}
