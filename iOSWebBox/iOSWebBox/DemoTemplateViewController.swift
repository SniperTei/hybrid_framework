//
//  DemoTemplateViewController.swift
//  iOSWebBox
//
//  模板示范容器（coconut_templates.json 的 "demo" 模板，v3.5.0）。
//  iOS 有真继承 —— 模板 = CoconutWebViewController 子类，展示三个扩展点：
//

import UIKit
import CoconutSDK

final class DemoTemplateViewController: CoconutWebViewController {

    // 1) 三级合并第 2 级：模板默认 NavConfig（forward header 仍可逐字段覆盖它）
    override var defaultNavConfig: NavConfig {
        NavConfig(visible: true, titleMode: .fixed("模板容器"), closePolicy: .always)
    }

    // 2) onBack 拦截钩子（对齐 protected 方法规范）：返回 true = 吞掉本次返回。
    //    示范：首次返回弹确认，确认后走默认返回语义。
    private var hasConfirmedBack = false
    override func onBack() -> Bool {
        if hasConfirmedBack { return false }  // 放行默认返回
        let alert = UIAlertController(title: "模板拦截", message: "onBack() 拦截示范：确认离开？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "离开", style: .default) { [weak self] _ in
            self?.hasConfirmedBack = true
            self?.handleBack()
        })
        alert.addAction(UIAlertAction(title: "留下", style: .cancel))
        present(alert, animated: true)
        return true
    }

    // 3) 宿主自定义 UI：底部 native banner（overlay，不占 webView 布局）
    private var didAddBanner = false

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !didAddBanner else { return }
        didAddBanner = true

        let banner = UIView()
        banner.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.92)
        let label = UILabel()
        label.text = "🥥 模板底部 Native Banner — DemoTemplateViewController"
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        banner.addSubview(label)
        banner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            banner.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            banner.heightAnchor.constraint(equalToConstant: 40),
            label.centerXAnchor.constraint(equalTo: banner.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: banner.centerYAnchor),
        ])
    }
}
