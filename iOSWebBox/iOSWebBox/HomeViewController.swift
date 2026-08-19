//
//  HomeViewController.swift
//  iOSWebBox
//
//  入口页（对标 Android MainActivity）：两个按钮，
//  一个打开 bundle 里的 coconut_index.html，另一个打开 Vite dev server。
//

import UIKit
import CoconutSDK

class HomeViewController: UIViewController {

    private var manifestUrlField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        // ---- 标题 ----
        let titleLabel = UILabel()
        titleLabel.text = "🥥 Coconut SDK"
        titleLabel.font = .systemFont(ofSize: 32, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // ---- 副标题 ----
        let subtitleLabel = UILabel()
        subtitleLabel.text = "跨平台混合应用框架"
        subtitleLabel.font = .systemFont(ofSize: 16)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)

        // ---- Hello ----
        let helloLabel = UILabel()
        helloLabel.text = "Hello World!"
        helloLabel.font = .systemFont(ofSize: 24, weight: .bold)
        helloLabel.textColor = .label
        helloLabel.textAlignment = .center
        helloLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(helloLabel)

        // ---- 描述 ----
        let descLabel = UILabel()
        descLabel.text = "点击下方按钮打开 Coconut WebView,体验 H5 与 Native 的交互"
        descLabel.font = .systemFont(ofSize: 14)
        descLabel.textColor = .secondaryLabel
        descLabel.textAlignment = .center
        descLabel.numberOfLines = 0
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(descLabel)

        // ---- 按钮 1：打开 Coconut WebView（bundle HTML） ----
        let openWebViewBtn = makeButton(title: "打开 Coconut WebView", primary: true)
        openWebViewBtn.addTarget(self, action: #selector(openBundleWebView), for: .touchUpInside)
        view.addSubview(openWebViewBtn)

        // ---- 按钮 2：打开本地测试页面（Vite dev server） ----
        let openLocalBtn = makeButton(title: "打开本地测试页面", primary: false)
        openLocalBtn.addTarget(self, action: #selector(openDevServer), for: .touchUpInside)
        view.addSubview(openLocalBtn)

        // ---- 按钮 3：打开离线包（coconut:// scheme） ----
        let openOfflineBtn = makeButton(title: "打开离线包 (coconut://)", primary: false)
        openOfflineBtn.addTarget(self, action: #selector(openOfflinePackage), for: .touchUpInside)
        view.addSubview(openOfflineBtn)

        // ---- 热更新 manifest URL 输入框 ----
        manifestUrlField = UITextField()
        manifestUrlField.text = "http://localhost:8000/manifest.json"
        manifestUrlField.font = .systemFont(ofSize: 13)
        manifestUrlField.borderStyle = .roundedRect
        manifestUrlField.autocapitalizationType = .none
        manifestUrlField.autocorrectionType = .no
        manifestUrlField.keyboardType = .URL
        manifestUrlField.textAlignment = .center
        manifestUrlField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(manifestUrlField)

        // ---- 按钮 4：检查热更新 ----
        let checkUpdateBtn = makeButton(title: "检查热更新", primary: false)
        checkUpdateBtn.addTarget(self, action: #selector(checkHotUpdate), for: .touchUpInside)
        view.addSubview(checkUpdateBtn)

        // ---- 按钮 5：回滚到内置版本 ----
        let rollbackBtn = makeButton(title: "回滚到内置版本", primary: false)
        rollbackBtn.addTarget(self, action: #selector(rollbackHotUpdate), for: .touchUpInside)
        view.addSubview(rollbackBtn)

        // ---- 版本信息 ----
        let versionLabel = UILabel()
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        versionLabel.text = "Coconut SDK v\(version)"
        versionLabel.font = .systemFont(ofSize: 12)
        versionLabel.textColor = .secondaryLabel
        versionLabel.textAlignment = .center
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(versionLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            helloLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 48),
            helloLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            descLabel.topAnchor.constraint(equalTo: helloLabel.bottomAnchor, constant: 24),
            descLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            descLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            openWebViewBtn.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 32),
            openWebViewBtn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            openWebViewBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            openWebViewBtn.heightAnchor.constraint(equalToConstant: 56),

            openLocalBtn.topAnchor.constraint(equalTo: openWebViewBtn.bottomAnchor, constant: 16),
            openLocalBtn.leadingAnchor.constraint(equalTo: openWebViewBtn.leadingAnchor),
            openLocalBtn.trailingAnchor.constraint(equalTo: openWebViewBtn.trailingAnchor),
            openLocalBtn.heightAnchor.constraint(equalToConstant: 56),

            openOfflineBtn.topAnchor.constraint(equalTo: openLocalBtn.bottomAnchor, constant: 16),
            openOfflineBtn.leadingAnchor.constraint(equalTo: openWebViewBtn.leadingAnchor),
            openOfflineBtn.trailingAnchor.constraint(equalTo: openWebViewBtn.trailingAnchor),
            openOfflineBtn.heightAnchor.constraint(equalToConstant: 56),

            manifestUrlField.topAnchor.constraint(equalTo: openOfflineBtn.bottomAnchor, constant: 24),
            manifestUrlField.leadingAnchor.constraint(equalTo: openWebViewBtn.leadingAnchor),
            manifestUrlField.trailingAnchor.constraint(equalTo: openWebViewBtn.trailingAnchor),
            manifestUrlField.heightAnchor.constraint(equalToConstant: 36),

            checkUpdateBtn.topAnchor.constraint(equalTo: manifestUrlField.bottomAnchor, constant: 12),
            checkUpdateBtn.leadingAnchor.constraint(equalTo: openWebViewBtn.leadingAnchor),
            checkUpdateBtn.trailingAnchor.constraint(equalTo: openWebViewBtn.trailingAnchor),
            checkUpdateBtn.heightAnchor.constraint(equalToConstant: 48),

            rollbackBtn.topAnchor.constraint(equalTo: checkUpdateBtn.bottomAnchor, constant: 8),
            rollbackBtn.leadingAnchor.constraint(equalTo: openWebViewBtn.leadingAnchor),
            rollbackBtn.trailingAnchor.constraint(equalTo: openWebViewBtn.trailingAnchor),
            rollbackBtn.heightAnchor.constraint(equalToConstant: 48),

            versionLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            versionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    private func makeButton(title: String, primary: Bool) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: primary ? .bold : .regular)
        btn.layer.cornerRadius = 12
        if primary {
            btn.backgroundColor = .systemBlue
            btn.setTitleColor(.white, for: .normal)
        } else {
            btn.backgroundColor = .clear
            btn.layer.borderWidth = 1
            btn.layer.borderColor = UIColor.systemBlue.cgColor
            btn.setTitleColor(.systemBlue, for: .normal)
        }
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }

    // MARK: - Actions

    /// 打开 bundle 里的 coconut_index.html（对标 Android openCoconutWebView + 旧 SceneDelegate 逻辑）
    @objc private func openBundleWebView() {
        let url: String
        if let html = Bundle.main.url(forResource: "coconut_index", withExtension: "html") {
            url = html.absoluteString
        } else {
            // Fallback to environment default if bundle resource is missing.
            url = CoconutConfig.shared.environment.defaultH5Domain
        }
        presentWebVC(with: url)
    }

    /// 打开 Vite dev server（对标 Android openLocalTestPage）
    @objc private func openDevServer() {
        presentWebVC(with: "http://localhost:5174/")
    }

    /// 打开离线包（coconut:// scheme，对标 Android openOfflinePackage）
    @objc private func openOfflinePackage() {
        presentWebVC(with: "coconut://demo/index.html")
    }

    // MARK: - 热更新（对标 Android checkHotUpdate / rollbackHotUpdate）

    /// 检查热更新；有更新则自动下载 + 应用
    @objc private func checkHotUpdate() {
        view.endEditing(true)
        let manifestUrl = (manifestUrlField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !manifestUrl.isEmpty else {
            showAlert(title: "热更新", message: "Manifest URL 为空")
            return
        }
        showAlert(title: "热更新", message: "检查更新中...")
        Task { @MainActor in
            let check = await CoconutUpdateManager.shared.checkUpdate(moduleId: "demo", manifestUrl: manifestUrl)
            if let error = check.error {
                showAlert(title: "检查失败", message: error)
                return
            }
            guard check.available, let manifest = check.manifest else {
                showAlert(title: "无更新", message: "当前版本 \(check.currentVersion)")
                return
            }
            let baseUrl = manifestUrl.substringBeforeLastSlash()
            let result = await CoconutUpdateManager.shared.performUpdate(manifest: manifest, baseUrl: baseUrl)
            if result.success {
                showAlert(title: "更新成功", message: "\(check.currentVersion) → \(result.version)")
            } else {
                showAlert(title: "更新失败", message: result.error ?? "unknown error")
            }
        }
    }

    /// 回滚到内置离线包
    @objc private func rollbackHotUpdate() {
        Task { @MainActor in
            let ok = await CoconutUpdateManager.shared.rollback(moduleId: "demo")
            if ok {
                let version = CoconutUpdateManager.shared.currentVersion(moduleId: "demo")
                showAlert(title: "已回滚", message: "回落内置版本 v\(version)")
            } else {
                showAlert(title: "回滚失败", message: "见日志")
            }
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func presentWebVC(with urlString: String) {
        let webVC = CoconutWebViewController()
        webVC.enableDebug = true
        webVC.loadViewIfNeeded()

        // 浮层关闭按钮（不修改 CoconutSDK 模块的 CoconutWebViewController）
        let closeBtn = UIButton(type: .system)
        closeBtn.setTitle("✕", for: .normal)
        closeBtn.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        closeBtn.setTitleColor(.white, for: .normal)
        closeBtn.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        closeBtn.layer.cornerRadius = 18
        closeBtn.layer.masksToBounds = true
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.addTarget(self, action: #selector(dismissWebVC), for: .touchUpInside)
        webVC.view.addSubview(closeBtn)
        NSLayoutConstraint.activate([
            closeBtn.widthAnchor.constraint(equalToConstant: 36),
            closeBtn.heightAnchor.constraint(equalToConstant: 36),
            closeBtn.topAnchor.constraint(equalTo: webVC.view.safeAreaLayoutGuide.topAnchor, constant: 8),
            closeBtn.trailingAnchor.constraint(equalTo: webVC.view.trailingAnchor, constant: -16),
        ])

        webVC.modalPresentationStyle = .fullScreen
        present(webVC, animated: true) {
            webVC.loadUrl(urlString)
        }
    }

    @objc private func dismissWebVC() {
        presentedViewController?.dismiss(animated: true)
    }
}

private extension String {
    func substringBeforeLastSlash() -> String {
        guard let idx = lastIndex(of: "/") else { return self }
        return String(self[..<idx])
    }
}
