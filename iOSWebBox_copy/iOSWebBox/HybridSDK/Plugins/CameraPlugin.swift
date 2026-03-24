import Foundation
import UIKit
import AVFoundation
import Photos

/// 相机插件
public class CameraPlugin: BasePlugin {
    private var currentCallback: PluginCallback?
    private var tempFilePath: String?

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
            callback.error(code: "UNKNOWN_ACTION", message: "Unknown action: \(action)")
        }
    }

    /// 拍照
    private func capture(params: [String: Any], callback: PluginCallback) {
        runOnMainThread {
            // 检查相机权限
            let authStatus = AVCaptureDevice.authorizationStatus(for: .video)

            switch authStatus {
            case .authorized:
                self.presentCamera(callback: callback)
            case .denied, .restricted:
                callback.error(code: "PERMISSION_DENIED", message: "Camera permission denied")
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    self.runOnMainThread {
                        if granted {
                            self.presentCamera(callback: callback)
                        } else {
                            callback.error(code: "PERMISSION_DENIED", message: "Camera permission denied")
                        }
                    }
                }
            @unknown default:
                callback.error(code: "UNKNOWN_ERROR", message: "Unknown authorization status")
            }
        }
    }

    /// 检查相机是否可用
    private func isAvailable(callback: PluginCallback) {
        let isAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)
        callback.success(["isAvailable": isAvailable])
    }

    /// 展示相机界面
    private func presentCamera(callback: PluginCallback) {
        guard let viewController = getViewController() else {
            callback.error(code: "ERROR", message: "ViewController not available")
            return
        }

        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        picker.allowsEditing = false

        currentCallback = callback

        viewController.present(picker, animated: true)
    }

    /// 保存图片到应用沙盒
    private func saveImageToDocuments(image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            return nil
        }

        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let fileName = "photo_\(Int(Date().timeIntervalSince1970)).jpg"
        let filePath = (documentsPath as NSString).appendingPathComponent(fileName)

        do {
            try data.write(to: URL(fileURLWithPath: filePath))
            return filePath
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }
    }
}

// MARK: - UIImagePickerControllerDelegate
extension CameraPlugin: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    public func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true)

        guard let image = info[.originalImage] as? UIImage,
              let callback = currentCallback else {
            currentCallback?.error(code: "ERROR", message: "Failed to capture image")
            currentCallback = nil
            return
        }

        // 保存图片到应用沙盒
        if let filePath = saveImageToDocuments(image: image) {
            tempFilePath = filePath
            callback.success([
                "path": "file://\(filePath)",
                "width": Int(image.size.width),
                "height": Int(image.size.height)
            ])
        } else {
            callback.error(code: "ERROR", message: "Failed to save image")
        }

        currentCallback = nil
    }

    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        currentCallback?.cancel()
        currentCallback = nil
    }
}
