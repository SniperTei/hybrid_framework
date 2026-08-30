//
//  ViewController.swift
//  CoconutiOSApp
//
//  Created by zhengnan on 2026/8/29.
//

import UIKit
import CoconutSDK

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        let containerButton = UIButton(type: .system)
        containerButton.setTitle("打开 Coconut 容器", for: .normal)

        // H5 App（真实业务试点 Phase 4）：离线包模块 h5app 随 CoconutSDK
        // SPM Resources 到位（coconut-web/h5app/），coconut:// 走 SDK 本地服务
        let h5AppButton = UIButton(type: .system)
        h5AppButton.setTitle("H5 App (4 tab)", for: .normal)

        for button in [containerButton, h5AppButton] {
            button.titleLabel?.font = .boldSystemFont(ofSize: 17)
            button.backgroundColor = UIColor.systemBlue
            button.setTitleColor(.white, for: .normal)
            button.layer.cornerRadius = 10
        }
        containerButton.addTarget(self, action: #selector(openContainer), for: .touchUpInside)
        h5AppButton.addTarget(self, action: #selector(openH5App), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [containerButton, h5AppButton])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerButton.heightAnchor.constraint(equalToConstant: 50),
            h5AppButton.heightAnchor.constraint(equalToConstant: 50),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            view.trailingAnchor.constraint(greaterThanOrEqualTo: stack.trailingAnchor, constant: 24),
        ])
    }

    /// 打开 bundle 里的 coconut_index.html（H5 三件套随 app 打包）
    @objc private func openContainer() {
        guard let html = Bundle.main.url(forResource: "coconut_index", withExtension: "html") else {
            print("[CoconutiOSApp] coconut_index.html not found in bundle")
            return
        }
        let webVC = CoconutWebViewController()
        webVC.enableDebug = true
        webVC.modalPresentationStyle = .fullScreen
        present(webVC, animated: true) {
            webVC.loadUrl(html.absoluteString)
        }
    }

    /// H5 App（真实业务试点）：coconut:// 离线包模块 h5app
    @objc private func openH5App() {
        let webVC = CoconutWebViewController()
        webVC.enableDebug = true
        webVC.modalPresentationStyle = .fullScreen
        present(webVC, animated: true) {
            webVC.loadUrl("coconut://h5app/index.html")
        }
    }
}
