//
//  GalleryPlugin.swift
//  iOSWebBox
//
//  Gallery picker plugin using PHPickerViewController
//

import Foundation
import UIKit
import PhotosUI

@available(iOS 14.0, *)
public class GalleryPlugin: BasePlugin {
    private var currentCallback: PluginCallback?
    private var pickerDelegate: GalleryPickerDelegate?

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
            super.exec(action: action, params: params, callback: callback)
        }
    }

    private func isAvailable(callback: PluginCallback) {
        callback.success(true)
    }

    private func pick(params: [String: Any], callback: PluginCallback) {
        guard let context = pluginContext else {
            callback.error("ERROR", message: "Invalid context")
            return
        }

        currentCallback = callback

        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.selectionLimit = optInt(params, "limit") ?? 1
        configuration.filter = .images

        let picker = PHPickerViewController(configuration: configuration)

        let delegate = GalleryPickerDelegate { [weak self] images in
            guard let self = self,
                  let callback = self.currentCallback else { return }

            if let images = images, !images.isEmpty {
                callback.success(["images": images])
            } else {
                callback.error("CANCELLED", message: "User cancelled or failed to load images")
            }
            self.currentCallback = nil
        }

        self.pickerDelegate = delegate
        picker.delegate = delegate

        // Store delegate in picker to prevent deallocation
        objc_setAssociatedObject(picker, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)

        context.viewController.present(picker, animated: true)
    }
}

// MARK: - Gallery Picker Delegate
@available(iOS 14.0, *)
private class GalleryPickerDelegate: NSObject, PHPickerViewControllerDelegate {
    private let completionHandler: ([[String: Any]]?) -> Void

    init(completionHandler: @escaping ([[String: Any]]?) -> Void) {
        self.completionHandler = completionHandler
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true) {
            guard !results.isEmpty else {
                self.completionHandler(nil)
                return
            }

            let group = DispatchGroup()
            var images: [[String: Any]] = []
            let lock = NSLock()

            for result in results {
                group.enter()
                result.itemProvider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, error in
                    defer { group.leave() }

                    if let error = error {
                        print("Error loading image: \(error)")
                        return
                    }

                    var imagePath: String?
                    if let url = item as? URL {
                        imagePath = self.saveImage(fromURL: url)
                    } else if let data = item as? Data,
                              let image = UIImage(data: data) {
                        imagePath = self.saveImage(image: image)
                    }

                    if let path = imagePath {
                        let filename = (path as NSString).lastPathComponent
                        let imageInfo = ["path": path, "filename": filename]
                        lock.lock()
                        images.append(imageInfo)
                        lock.unlock()
                    }
                }
            }

            group.notify(queue: .main) {
                self.completionHandler(images.isEmpty ? nil : images)
            }
        }
    }

    private func saveImage(fromURL url: URL) -> String? {
        do {
            let data = try Data(contentsOf: url)
            return saveImage(data: data)
        } catch {
            print("Error loading image from URL: \(error)")
            return nil
        }
    }

    private func saveImage(image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        return saveImage(data: data)
    }

    private func saveImage(data: Data) -> String? {
        let filename = "gallery_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(8)).jpg"
        let path = (NSTemporaryDirectory() as NSString).appendingPathComponent(filename)

        do {
            try data.write(to: URL(fileURLWithPath: path))
            return path
        } catch {
            print("Error saving image: \(error)")
            return nil
        }
    }
}
