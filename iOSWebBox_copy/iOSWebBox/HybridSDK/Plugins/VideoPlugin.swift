import Foundation
import UIKit
import AVFoundation
import Photos
import MobileCoreServices

/// 视频录制插件
public class VideoPlugin: BasePlugin {
    private var currentCallback: PluginCallback?
    private var tempFilePath: String?

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
            callback.error(code: "UNKNOWN_ACTION", message: "Unknown action: \(action)")
        }
    }

    /// 录制视频
    private func record(params: [String: Any], callback: PluginCallback) {
        runOnMainThread {
            // 检查相机和麦克风权限
            let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
            let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)

            if cameraStatus != .authorized {
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    self.runOnMainThread {
                        if granted {
                            self.checkMicrophoneAndPresent(callback: callback)
                        } else {
                            callback.error(code: "PERMISSION_DENIED", message: "Camera permission denied")
                        }
                    }
                }
                return
            }

            if microphoneStatus != .authorized {
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    self.runOnMainThread {
                        if granted {
                            self.presentVideoRecorder(callback: callback)
                        } else {
                            callback.error(code: "PERMISSION_DENIED", message: "Microphone permission denied")
                        }
                    }
                }
                return
            }

            self.presentVideoRecorder(callback: callback)
        }
    }

    /// 检查麦克风权限
    private func checkMicrophoneAndPresent(callback: PluginCallback) {
        let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)

        if microphoneStatus != .authorized {
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                self.runOnMainThread {
                    if granted {
                        self.presentVideoRecorder(callback: callback)
                    } else {
                        callback.error(code: "PERMISSION_DENIED", message: "Microphone permission denied")
                    }
                }
            }
        } else {
            presentVideoRecorder(callback: callback)
        }
    }

    /// 检查录制是否可用
    private func isAvailable(callback: PluginCallback) {
        let isAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)
        callback.success(["isAvailable": isAvailable])
    }

    /// 展示视频录制界面
    private func presentVideoRecorder(callback: PluginCallback) {
        guard let viewController = getViewController() else {
            callback.error(code: "ERROR", message: "ViewController not available")
            return
        }

        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            callback.error(code: "UNAVAILABLE", message: "Camera not available")
            return
        }

        let mediaTypes = [kUTTypeMovie as String]
        guard UIImagePickerController.availableMediaTypes(for: .camera)?.contains(kUTTypeMovie as String) == true else {
            callback.error(code: "UNAVAILABLE", message: "Video recording not supported")
            return
        }

        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = mediaTypes
        picker.delegate = self
        picker.allowsEditing = false
        picker.videoMaximumDuration = 300 // 默认最大5分钟

        currentCallback = callback

        viewController.present(picker, animated: true)
    }

    /// 保存视频到应用沙盒
    private func saveVideoToDocuments(url: URL) -> String? {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let fileName = "video_\(Int(Date().timeIntervalSince1970)).\(url.pathExtension)"
        let filePath = (documentsPath as NSString).appendingPathComponent(fileName)

        do {
            try FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: filePath))
            return filePath
        } catch {
            print("Failed to save video: \(error)")
            return nil
        }
    }

    /// 获取视频时长
    private func getVideoDuration(url: URL) -> Int {
        let asset = AVAsset(url: url)
        let duration = asset.duration
        return Int(CMTimeGetSeconds(duration))
    }

    /// 获取视频大小
    private func getVideoSize(url: URL) -> Int {
        do {
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
            if let fileSize = resourceValues.fileSize {
                return fileSize
            }
        } catch {
            print("Failed to get video size: \(error)")
        }
        return 0
    }
}

// MARK: - UIImagePickerControllerDelegate
extension VideoPlugin: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    public func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true)

        guard let mediaURL = info[.mediaURL] as? URL,
              let callback = currentCallback else {
            currentCallback?.error(code: "ERROR", message: "Failed to record video")
            currentCallback = nil
            return
        }

        // 保存视频到应用沙盒
        if let filePath = saveVideoToDocuments(url: mediaURL) {
            tempFilePath = filePath
            let fileURL = URL(fileURLWithPath: filePath)

            callback.success([
                "path": "file://\(filePath)",
                "duration": getVideoDuration(url: fileURL),
                "size": getVideoSize(url: fileURL)
            ])
        } else {
            callback.error(code: "ERROR", message: "Failed to save video")
        }

        currentCallback = nil
    }

    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        currentCallback?.cancel()
        currentCallback = nil
    }
}
