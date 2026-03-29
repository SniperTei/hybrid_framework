import Foundation
import UIKit

public class ComponentContext {

    public let applicationContext: UIApplication
    public var sdkVersion: String = "1.0.0"

    weak var host: ComponentHost?

    public init(applicationContext: UIApplication) {
        self.applicationContext = applicationContext
    }

    public var currentViewController: UIViewController? {
        return host?.getViewController()
    }

    public var currentWebView: Any? {
        return host?.getWebView()
    }

    public func getComponent(name: String) async -> CoconutPlugin? {
        return await ComponentManager.shared.getComponent(name: name)
    }
}
