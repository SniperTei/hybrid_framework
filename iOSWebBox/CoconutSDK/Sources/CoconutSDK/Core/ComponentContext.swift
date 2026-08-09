import Foundation
import UIKit
import WebKit

@MainActor
public class ComponentContext {

    public let applicationContext: UIApplication
    public var sdkVersion: String = "2.0.0"

    weak var host: ComponentHost?

    public init(applicationContext: UIApplication) {
        self.applicationContext = applicationContext
    }

    public var currentViewController: UIViewController? {
        return host?.getViewController()
    }

    public var currentWebView: WKWebView? {
        return host?.getWebView() as? WKWebView
    }

    public func getComponent(name: String) -> CoconutPlugin? {
        return ComponentManager.shared.getComponent(name: name)
    }
}
