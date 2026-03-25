//
//  PluginContext.swift
//  iOSWebBox
//
//  Plugin execution context
//

import UIKit
import WebKit

public class PluginContext {
    public let applicationContext: UIApplication
    public let webView: WKWebView
    public let viewController: UIViewController

    public init(applicationContext: UIApplication, webView: WKWebView, viewController: UIViewController) {
        self.applicationContext = applicationContext
        self.webView = webView
        self.viewController = viewController
    }
}
