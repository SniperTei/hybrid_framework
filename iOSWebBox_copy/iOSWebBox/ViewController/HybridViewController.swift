import UIKit

class HybridViewController: UIViewController {

    private var hybridWebView: HybridWebView!

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "iOSWebBox Demo"
        view.backgroundColor = .white

        setupWebView()
    }

    private func setupWebView() {
        // 创建配置
        let config = HybridConfig.Builder()
            .setDefaultURL("https://example.com/index.html")
            .setDebugMode(true)
            .setEnableCache(true)
            .setEnableDomStorage(true)
            .build()

        // 初始化WebView
        hybridWebView = HybridWebView(frame: view.bounds)
        hybridWebView.initConfig(config: config, viewController: self)

        // 注册插件
        hybridWebView.getPluginManager()?.registerPlugins([
            CameraPlugin(),
            GalleryPlugin(),
            VideoPlugin(),
            DevicePlugin(),
            NetworkPlugin()
        ])

        // 设置为视图
        hybridWebView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hybridWebView)

        // 加载本地示例页面
        if let htmlPath = Bundle.module.path(forResource: "index", ofType: "html", inDirectory: "html") {
            hybridWebView.loadFileURL(URL(fileURLWithPath: htmlPath), allowingReadAccessTo: URL(fileURLWithPath: htmlPath.deletingLastPathComponent().path))
        } else {
            // 加载远程URL
            hybridWebView.loadHybridURL(config.defaultURL)
        }

        // 设置错误监听
        hybridWebView.setErrorListener { [weak self] error, url in
            if let url = url {
                print("WebView error: \(error.localizedDescription) at URL: \(url)")
            } else {
                print("WebView error: \(error.localizedDescription)")
            }

            // 显示错误提示
            let alert = UIAlertController(
                title: "Error",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(alert, animated: true)
        }

        // 设置URL拦截器
        hybridWebView.setUrlInterceptor { url in
            print("URL intercepted: \(url)")
            return false
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        hybridWebView.frame = view.bounds
    }

    deinit {
        hybridWebView?.cleanup()
    }
}
