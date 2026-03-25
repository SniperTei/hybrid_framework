//
//  HybridViewController.swift
//  iOSWebBox
//
//  Hybrid demo view controller
//

import UIKit
import WebKit

class HybridViewController: UIViewController {

    private var hybridWebView: HybridWebView!

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "iOSWebBox"
        view.backgroundColor = .white

        setupWebView()
        loadDemoPage()
    }

    private func setupWebView() {
        hybridWebView = HybridWebView(frame: view.bounds)

        let config = HybridConfig.Builder()
            .setDefaultURL("about:blank")
            .setDebugMode(true)
            .build()

        hybridWebView.initConfig(config: config, viewController: self)

        // Register plugins
        hybridWebView.getPluginManager()?.registerPlugins([
            DevicePlugin(),
            CameraPlugin(),
            GalleryPlugin(),
            VideoPlugin(),
            NetworkPlugin()
        ])

        view.addSubview(hybridWebView)

        // Auto-layout
        hybridWebView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hybridWebView.topAnchor.constraint(equalTo: view.topAnchor),
            hybridWebView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hybridWebView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hybridWebView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func loadDemoPage() {
        // Load demo HTML from bundle
        if let htmlPath = Bundle.main.path(forResource: "index", ofType: "html", inDirectory: "resources/html"),
           let htmlContent = try? String(contentsOfFile: htmlPath) {
            hybridWebView.loadHTMLString(htmlContent, baseURL: nil)
        } else {
            // Fallback to loading from file URL
            if let htmlPath = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "resources/html") {
                hybridWebView.load(URLRequest(url: htmlPath))
            } else {
                print("Failed to find index.html")
            }
        }
    }
}
