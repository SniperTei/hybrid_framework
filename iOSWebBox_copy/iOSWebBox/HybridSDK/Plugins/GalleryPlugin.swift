import Foundation
import UIKit
import Photos
import PhotosUI

/// 相册插件
public class GalleryPlugin: BasePlugin {
    private var currentCallback: PluginCallback?
    private var maximumSelectionCount: Int = 1
    private var filterType: PHPickerFilter?

    public override func pluginName() -> String {
        return "gallery"
    }

    public override func exec(action: String, params: [String: Any], callback: PluginCallback) {
        switch action {
        case "pick":
            pick(params: params, callback: callback)
        case "isAvailable":
            isAvailable(callback: callback)
        default:
            callback.error(code: "UNKNOWN_ACTION", message: "Unknown action: \(action)")
        }
    }

    /// 选择照片/视频
    private func pick(params: [String: Any], callback: PluginCallback) {
        runOnMainThread {
            // 检查相册权限
            let authStatus = PHPhotoLibrary.authorizationStatus()

            switch authStatus {
            case .authorized, .limited:
                self.presentPicker(params: params, callback: callback)
            case .denied, .restricted:
                callback.error(code: "PERMISSION_DENIED", message: "Photo library permission denied")
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization { status in
                    self.runOnMainThread {
                        if status == .authorized || status == .limited {
                            self.presentPicker(params: params, callback: callback)
                        } else {
                            callback.error(code: "PERMISSION_DENIED", message: "Photo library permission denied")
                        }
                    }
                }
            @unknown default:
                callback.error(code: "UNKNOWN_ERROR", message: "Unknown authorization status")
            }
        }
    }

    /// 检查相册是否可用
    private func isAvailable(callback: PluginCallback) {
        callback.success(["isAvailable": true])
    }

    /// 展示选择器
    private func presentPicker(params: [String: Any], callback: PluginCallback) {
        guard let viewController = getViewController() else {
            callback.error(code: "ERROR", message: "ViewController not available")
            return
        }

        // 解析参数
        let maxCount = optInt(params, "maxCount", defaultValue: 1) ?? 1
        maximumSelectionCount = maxCount

        let mediaType = optString(params, "type", defaultValue: "all") ?? "all"

        // 设置过滤器
        switch mediaType {
        case "image":
            filterType = .images
        case "video":
            filterType = .videos
        default:
            filterType = nil // any
        }

        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = filterType
        configuration.selectionLimit = maximumSelectionCount

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self

        currentCallback = callback

        viewController.present(picker, animated: true)
    }

    /// 保存图片到应用沙盒
    private func saveImageToDocuments(itemProvider: NSItemProvider, completion: @escaping (String?) -> Void) {
        itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
            guard let url = url else {
                completion(nil)
                return
            }

            do {
                let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
                let fileName = "photo_\(Int(Date().timeIntervalSince1970)).\(url.pathExtension)"
                let destinationPath = (documentsPath as NSString).appendingPathComponent(fileName)
                let destinationURL = URL(fileURLWithPath: destinationPath)

                try FileManager.default.copyItem(at: url, to: destinationURL)
                completion(destinationPath)
            } catch {
                print("Failed to save image: \(error)")
                completion(nil)
            }
        }
    }

    /// 保存视频到应用沙盒
    private func saveVideoToDocuments(itemProvider: NSItemProvider, completion: @escaping (String?) -> Void) {
        itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
            guard let url = url else {
                completion(nil)
                return
            }

            do {
                let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
                let fileName = "video_\(Int(Date().timeIntervalSince1970)).\(url.pathExtension)"
                let destinationPath = (documentsPath as NSString).appendingPathComponent(fileName)
                let destinationURL = URL(fileURLWithPath: destinationPath)

                try FileManager.default.copyItem(at: url, to: destinationURL)
                completion(destinationPath)
            } catch {
                print("Failed to save video: \(error)")
                completion(nil)
            }
        }
    }
}

// MARK: - PHPickerViewControllerDelegate
extension GalleryPlugin: PHPickerViewControllerDelegate {
    public func picker(
        _ picker: PHPickerViewController,
        didFinishPicking results: [PHPickerResult]
    ) {
        picker.dismiss(animated: true)

        guard let callback = currentCallback else {
            return
        }

        if results.isEmpty {
            callback.cancel()
            currentCallback = nil
            return
        }

        // 处理选择结果
        let group = DispatchGroup()
        var items: [[String: Any]] = []

        for result in results {
            group.enter()
            let itemProvider = result.itemProvider

            if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                saveImageToDocuments(itemProvider: itemProvider) { path in
                    if let path = path {
                        items.append([
                            "path": "file://\(path)",
                            "type": "image"
                        ])
                    }
                    group.leave()
                }
            } else if itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                saveVideoToDocuments(itemProvider: itemProvider) { path in
                    if let path = path {
                        items.append([
                            "path": "file://\(path)",
                            "type": "video"
                        ])
                    }
                    group.leave()
                }
            } else {
                group.leave()
            }
        }

        group.notify(queue: .main) {
            callback.success([
                "items": items,
                "count": items.count
            ])
            self.currentCallback = nil
        }
    }
}
