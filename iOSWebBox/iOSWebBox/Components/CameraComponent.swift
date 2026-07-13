import Foundation
import UIKit
import AVFoundation
import ImageIO
import CoconutSDK

/**
 * Camera Component (iOS)
 *
 * Provides photo capture and QR/barcode scanning, plus a native confirm dialog.
 * API mirrors the Harmony CameraComponent so H5 calls are cross-platform identical.
 *
 * Functions:
 *   - takePhoto:   { frontCamera?: bool } -> { success, base64?, message? }
 *       base64 is a data URL (image/jpeg) ready for <img src>.
 *       Returns { success: false, message } when the user cancels.
 *   - scanQRCode:  { qrOnly?: bool } -> { success, codeType?, originalValue?, message? }
 *       qrOnly=true restricts the scanner to QR codes only.
 *   - isSupported: -> { takePhoto: bool, scanQRCode: bool }
 *   - showDialog:  { title?, message?, confirmText?, cancelText? } -> { confirmed: bool }
 *       Shows a native confirm dialog (same UX as the Harmony TestCustomDialog).
 *
 * Note: requires NSCameraUsageDescription in the host app's Info.plist.
 */
public class CameraComponent: BaseComponent {
    public init() { super.init() }

    override public var name: String { "camera" }
    override public var version: String { "1.0.0" }
    override public var pluginDescription: String { "Camera component for photo capture and QR code scanning" }

    private var componentContext: ComponentContext?

    override public func onInit(context: ComponentContext) async {
        componentContext = context
    }

    override public func handle(function: String, params: [String: Any]?) async throws -> [String: Any] {
        switch function {
        case "takePhoto":   return await takePhoto(params)
        case "scanQRCode":  return await scanQRCode(params)
        case "isSupported": return isSupported()
        case "showDialog":  return await showDialog(params)
        default: try functionNotSupportedError(function)
        }
    }

    // MARK: - takePhoto

    @MainActor
    private func takePhoto(_ params: [String: Any]?) async -> [String: Any] {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            return success(["success": false, "message": "Camera not available on this device"])
        }

        guard let vc = componentContext?.currentViewController else {
            return success(["success": false, "message": "No view controller available"])
        }

        let frontCamera = getBoolParam(params, "frontCamera", false)
        let cameraDevice: UIImagePickerController.CameraDevice = frontCamera ? .front : .rear

        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        if UIImagePickerController.isCameraDeviceAvailable(cameraDevice) {
            picker.cameraDevice = cameraDevice
        }

        let coordinator = PhotoCaptureCoordinator()
        picker.delegate = coordinator

        vc.present(picker, animated: true)

        return await withCheckedContinuation { continuation in
            coordinator.completion = { result in
                continuation.resume(returning: result)
            }
        }
    }

    // MARK: - scanQRCode

    @MainActor
    private func scanQRCode(_ params: [String: Any]?) async -> [String: Any] {
        guard let vc = componentContext?.currentViewController else {
            return success(["success": false, "message": "No view controller available"])
        }

        let qrOnly = getBoolParam(params, "qrOnly", false)

        do {
            let scanner = try QRScannerViewController(qrOnly: qrOnly)
            scanner.modalPresentationStyle = .fullScreen
            vc.present(scanner, animated: true)

            return await withCheckedContinuation { (continuation: CheckedContinuation<[String: Any], Never>) in
                scanner.resultHandler = { result in
                    continuation.resume(returning: result)
                }
            }
        } catch {
            return success(["success": false, "message": "Scanner unavailable: \(error.localizedDescription)"])
        }
    }

    // MARK: - isSupported

    private func isSupported() -> [String: Any] {
        return success([
            "takePhoto": UIImagePickerController.isSourceTypeAvailable(.camera),
            "scanQRCode": AVCaptureDevice.default(for: .video) != nil
        ])
    }

    // MARK: - showDialog

    @MainActor
    private func showDialog(_ params: [String: Any]?) async -> [String: Any] {
        let title = getParam(params, "title", "提示")
        let message = getParam(params, "message", "")
        let confirmText = getParam(params, "confirmText", "确定")
        let cancelText = getParam(params, "cancelText", "取消")

        guard let vc = componentContext?.currentViewController else {
            return success(["confirmed": false])
        }

        return await withCheckedContinuation { continuation in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: cancelText, style: .cancel) { _ in
                continuation.resume(returning: self.success(["confirmed": false]))
            })
            alert.addAction(UIAlertAction(title: confirmText, style: .default) { _ in
                continuation.resume(returning: self.success(["confirmed": true]))
            })
            vc.present(alert, animated: true)
        }
    }

    override public func onCleanup() async {
        componentContext = nil
    }
}

// MARK: - Photo capture coordinator

/// Wraps UIImagePickerController's delegate callback into an async result.
private class PhotoCaptureCoordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    var completion: (([String: Any]) -> Void)?
    private var hasCompleted = false

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let image = info[.originalImage] as? UIImage
        picker.dismiss(animated: true) { self.deliver(picker, image: image, cancelled: false) }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) { self.deliver(picker, image: nil, cancelled: true) }
    }

    private func deliver(_ picker: UIImagePickerController, image: UIImage?, cancelled: Bool) {
        guard !hasCompleted else { return }
        hasCompleted = true
        // Break the retain cycle: picker holds self via .delegate.
        picker.delegate = nil
        completion?(buildResult(image: image, cancelled: cancelled))
    }

    private func buildResult(image: UIImage?, cancelled: Bool) -> [String: Any] {
        if cancelled || image == nil {
            return ["success": false, "message": "User cancelled"]
        }
        let jpegData = CameraComponent.jpegData(for: image!) ?? Data()
        let base64 = jpegData.base64EncodedString()
        let dataUrl = "data:image/jpeg;base64,\(base64)"
        return ["success": true, "base64": dataUrl]
    }
}

// MARK: - JPEG encoding (iOS 15+ portable, preserves EXIF orientation)

extension CameraComponent {

    /// Encodes a UIImage to JPEG via ImageIO. Portable across iOS 15+ and
    /// honours the source image's imageOrientation via kCGImagePropertyOrientation.
    static func jpegData(for image: UIImage, quality: CGFloat = 0.8) -> Data? {
        guard let cgImage = image.cgImage else { return nil }
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData, "public.jpeg" as CFString, 1, nil) else {
            return nil
        }
        let properties: [CFString: Any] = [
            kCGImagePropertyOrientation: orientationValue(image.imageOrientation),
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutableData as Data
    }

    private static func orientationValue(_ ui: UIImage.Orientation) -> UInt32 {
        switch ui {
        case .up:            return CGImagePropertyOrientation.up.rawValue
        case .upMirrored:    return CGImagePropertyOrientation.upMirrored.rawValue
        case .down:          return CGImagePropertyOrientation.down.rawValue
        case .downMirrored:  return CGImagePropertyOrientation.downMirrored.rawValue
        case .left:          return CGImagePropertyOrientation.left.rawValue
        case .leftMirrored:  return CGImagePropertyOrientation.leftMirrored.rawValue
        case .right:         return CGImagePropertyOrientation.right.rawValue
        case .rightMirrored: return CGImagePropertyOrientation.rightMirrored.rawValue
        @unknown default:    return CGImagePropertyOrientation.up.rawValue
        }
    }
}

// MARK: - QR scanner

/// Full-screen QR/barcode scanner backed by AVCaptureSession + AVCaptureMetadataOutput.
private class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    private let session = AVCaptureSession()
    private let previewLayer = AVCaptureVideoPreviewLayer()
    var resultHandler: (([String: Any]) -> Void)?
    private var hasResumed = false
    private let qrOnly: Bool

    init(qrOnly: Bool) throws {
        self.qrOnly = qrOnly
        super.init(nibName: nil, bundle: nil)
        try setupSession()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupSession() throws {
        guard let device = AVCaptureDevice.default(for: .video) else {
            throw NSError(domain: "CameraComponent", code: 1, userInfo: [NSLocalizedDescriptionKey: "No camera device"])
        }
        let input = try AVCaptureDeviceInput(device: device)
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = qrOnly ? [.qr] : availableMetadataTypes(for: output)

        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
    }

    private func availableMetadataTypes(for output: AVCaptureMetadataOutput) -> [AVMetadataObject.ObjectType] {
        let supported = output.availableMetadataObjectTypes
        let wanted: [AVMetadataObject.ObjectType] = [.qr, .aztec, .dataMatrix, .pdf417,
                                                     .upce, .code39, .code39Mod43,
                                                     .code93, .code128, .ean8, .ean13, .itf14]
        return supported.filter { wanted.contains($0) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        // Close button so the user can cancel scanning.
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("取消", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        closeButton.layer.cornerRadius = 8
        closeButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        closeButton.sizeToFit()
        closeButton.frame.origin = CGPoint(x: 24, y: view.safeAreaInsets.top + 16)
        closeButton.autoresizingMask = [.flexibleLeftMargin, .flexibleBottomMargin]
        closeButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        view.addSubview(closeButton)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
    }

    @objc private func cancelTapped() {
        finish(success: false, codeType: nil, value: nil, message: "User cancelled")
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue else { return }
        let type = stringForType(obj.type)
        finish(success: true, codeType: type, value: value, message: nil)
    }

    private func finish(success: Bool, codeType: String?, value: String?, message: String?) {
        guard !hasResumed else { return }
        hasResumed = true
        session.stopRunning()
        dismiss(animated: true) {
            self.resultHandler?(self.buildResult(success: success, codeType: codeType,
                                                 value: value, message: message))
        }
    }

    private func buildResult(success: Bool, codeType: String?, value: String?, message: String?) -> [String: Any] {
        var dict: [String: Any] = ["success": success]
        if let codeType = codeType { dict["codeType"] = codeType }
        if let value = value { dict["originalValue"] = value }
        if let message = message { dict["message"] = message }
        return dict
    }

    private func stringForType(_ type: AVMetadataObject.ObjectType) -> String {
        switch type {
        case .qr: return "QR_CODE"
        case .ean13: return "EAN_13"
        case .ean8: return "EAN_8"
        case .code128: return "CODE_128"
        case .code39: return "CODE_39"
        case .code93: return "CODE_93"
        case .upce: return "UPC_E"
        case .pdf417: return "PDF_417"
        case .aztec: return "AZTEC"
        case .dataMatrix: return "DATA_MATRIX"
        case .itf14: return "ITF_14"
        default: return type.rawValue
        }
    }
}
