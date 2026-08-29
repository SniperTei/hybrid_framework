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

        let button = UIButton(type: .system)
        button.setTitle("打开 Coconut 容器", for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 17)
        button.backgroundColor = UIColor.systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(openContainer), for: .touchUpInside)
        view.addSubview(button)

        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            button.heightAnchor.constraint(equalToConstant: 50),
            button.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            view.trailingAnchor.constraint(greaterThanOrEqualTo: button.trailingAnchor, constant: 24),
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
}
