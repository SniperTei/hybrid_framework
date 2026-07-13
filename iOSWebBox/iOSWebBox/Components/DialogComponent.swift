import Foundation
import UIKit
import CoconutSDK

public class DialogComponent: BaseComponent {
    public init() { super.init() }

    override public var name: String { "dialog" }
    override public var version: String { "1.0.0" }
    override public var pluginDescription: String { "Native dialog and toast component" }

    private var componentContext: ComponentContext?
    private var loadingAlert: UIAlertController?

    override public func onInit(context: ComponentContext) async {
        componentContext = context
    }

    override public func handle(function: String, params: [String: Any]?) async throws -> [String: Any] {
        switch function {
        case "alert": return await showAlert(params)
        case "confirm": return await showConfirm(params)
        case "toast": return await showToast(params)
        case "showLoading": return await showLoading(params)
        case "hideLoading": return await hideLoading()
        default: try functionNotSupportedError(function)
        }
    }

    @MainActor
    private func showAlert(_ params: [String: Any]?) async -> [String: Any] {
        let title = getParam(params, "title", "提示")
        let message = getParam(params, "message", "")
        let buttonText = getParam(params, "buttonText", "确定")

        guard let vc = componentContext?.currentViewController else {
            return success(["confirmed": false])
        }

        return await withCheckedContinuation { continuation in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: buttonText, style: .default) { _ in
                continuation.resume(returning: self.success(["confirmed": true]))
            })
            vc.present(alert, animated: true)
        }
    }

    @MainActor
    private func showConfirm(_ params: [String: Any]?) async -> [String: Any] {
        let title = getParam(params, "title", "确认")
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

    @MainActor
    private func showToast(_ params: [String: Any]?) -> [String: Any] {
        let message = getParam(params, "message", "")
        let duration = getDoubleParam(params, "duration", 2.0)
        let position = getParam(params, "position", "bottom")

        guard let vc = componentContext?.currentViewController else {
            return success(["success": false])
        }

        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 14)
        label.numberOfLines = 0
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.sizeToFit()
        let padding: CGFloat = 16
        label.frame.size.width += padding * 2
        label.frame.size.height += padding
        label.center.x = vc.view.bounds.width / 2

        switch position {
        case "top":
            label.frame.origin.y = vc.view.safeAreaInsets.top + 20
        case "center":
            label.center.y = vc.view.bounds.height / 2
        default:
            label.frame.origin.y = vc.view.bounds.height - vc.view.safeAreaInsets.bottom - 80
        }

        vc.view.addSubview(label)
        UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut) {
            label.alpha = 0
        } completion: { _ in
            label.removeFromSuperview()
        }

        return success(["success": true])
    }

    @MainActor
    private func showLoading(_ params: [String: Any]?) -> [String: Any] {
        let message = getParam(params, "message", "加载中...")

        guard let vc = componentContext?.currentViewController else {
            return success(["success": false])
        }

        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.startAnimating()
        alert.view.addSubview(indicator)
        indicator.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor, constant: -40).isActive = true
        indicator.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -10).isActive = true

        loadingAlert = alert
        vc.present(alert, animated: true)
        return success(["success": true])
    }

    @MainActor
    private func hideLoading() -> [String: Any] {
        loadingAlert?.dismiss(animated: true)
        loadingAlert = nil
        return success(["success": true])
    }

    private func getDoubleParam(_ params: [String: Any]?, _ key: String, _ defaultValue: Double = 0) -> Double {
        guard let value = params?[key] else { return defaultValue }
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let s = value as? String, let d = Double(s) { return d }
        return defaultValue
    }

    override public func onCleanup() async {
        componentContext = nil
        await MainActor.run {
            loadingAlert?.dismiss(animated: true)
            loadingAlert = nil
        }
    }
}
