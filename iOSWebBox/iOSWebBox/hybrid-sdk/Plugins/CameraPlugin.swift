//
//  CameraPlugin.swift
//  iOSWebBox
//
//  Camera plugin
//

import Foundation
import UIKit
import AVFoundation

public class CameraPlugin: BasePlugin {
    private var currentCallback: PluginCallback?

    public override func pluginName() -> String {
        return "camera"
    }

    public override func exec(action: String, params: [String: Any], callback: PluginCallback) {
        switch action {
        case "capture":
            capture(params: params, callback: callback)
        case "isAvailable":
            isAvailable(callback: callback)
        default:
            super.exec(action: action, params: params, callback: callback)
        }
    }

    private func isAvailable(callback: PluginCallback) {
        callback.success(UIImagePickerController.isSourceTypeAvailable(.camera))
    }

    private func capture(params: [String: Any], callback: PluginCallback) {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            callback.error("UNAVAILABLE", message: "Camera not available")
            return
        }

        // Check camera permission
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            presentCamera(callback: callback)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.presentCamera(callback: callback)
                    } else {
                        callback.error("PERMISSION_DENIED", message: "Camera permission denied")
                    }
                }
            }
        default:
            callback.error("PERMISSION_DENIED", message: "Camera permission denied")
        }
    }

    private func presentCamera(callback: PluginCallback) {
        guard let context = pluginContext else {
            callback.error("ERROR", message: "Invalid context")
            return
        }

        currentCallback = callback

        let pickerDelegate = CameraPickerDelegate { [weak self] image in
            guard let self = self,
                  let callback = self.currentCallback else { return }

            if let image = image {
                self.saveImage(image: image, callback: callback)
            } else {
                callback.error("CANCELLED", message: "User cancelled")
            }
            self.currentCallback = nil
        }

        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = pickerDelegate
        picker.cameraCaptureMode = .photo

        // Store delegate to prevent deallocation
        objc_setAssociatedObject(picker, "delegate", pickerDelegate, .OBJC_ASSOCIATION_RETAIN)

        context.viewController.present(picker, animated: true)
    }

    private func saveImage(image: UIImage, callback: PluginCallback) {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            callback.error("ERROR", message: "Failed to process image")
            return
        }

        let filename = "camera_\(Int(Date().timeIntervalSince1970)).jpg"
        let path = (NSTemporaryDirectory() as NSString).appendingPathComponent(filename)

        do {
            try data.write(to: URL(fileURLWithPath: path))
            callback.success(["path": path, "filename": filename])
        } catch {
            callback.error("ERROR", message: "Failed to save image: \(error.localizedDescription)")
        }
    }
}

// MARK: - Camera Picker Delegate
private class CameraPickerDelegate: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let completionHandler: (UIImage?) -> Void

    init(completionHandler: @escaping (UIImage?) -> Void) {
        self.completionHandler = completionHandler
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true) {
            let image = info[.originalImage] as? UIImage
            self.completionHandler(image)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) {
            self.completionHandler(nil)
        }
    }
}
