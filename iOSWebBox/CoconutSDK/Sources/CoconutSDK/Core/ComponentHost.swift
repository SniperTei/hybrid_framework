import Foundation
import UIKit

public protocol ComponentHost: AnyObject {
    func getViewController() -> UIViewController?
    func getWebView() -> Any?
    func runOnMainThread(_ action: @escaping () -> Void)
}
