//
//  SniperYoloAPIViewController.swift
//  iOSWebBox
//
//  Sniper YOLO API 冒烟（Native）— CoconutNetwork 引擎 Swift 直调演示，
//  对标 Android SniperYoloAPIActivity。与 WebView / bridge 全链路
//  （NetworkComponent）互补：这里验证的是引擎作为独立库在纯 native
//  消费者场景下的表现（v3.4.0 架构的 native-first 用法，同热更新下载）。
//

import UIKit
import CoconutNetwork

final class SniperYoloAPIViewController: UIViewController {

    // ---- 状态 ----
    private let client = HttpClient(HttpConfig())
    private var token: String?
    private var createdFoodId: String?
    private var stepButtons: [UIButton] = []

    // ---- UI ----
    private var baseUrlField: UITextField!
    private var logView: UITextView!
    private let defaultBase = "http://127.0.0.1:8041/api/v1"
    private let timeoutMs = 15_000

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - UI

    private func setupUI() {
        view.backgroundColor = .systemBackground

        // ---- 顶栏：返回 + 标题 ----
        let backButton = UIButton(type: .system)
        backButton.setTitle("‹ 返回", for: .normal)
        backButton.titleLabel?.font = .systemFont(ofSize: 17)
        backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backButton)

        let titleLabel = UILabel()
        titleLabel.text = "Sniper API 冒烟"
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // ---- base URL 输入框 ----
        baseUrlField = UITextField()
        baseUrlField.text = defaultBase
        baseUrlField.font = .systemFont(ofSize: 13)
        baseUrlField.borderStyle = .roundedRect
        baseUrlField.autocapitalizationType = .none
        baseUrlField.autocorrectionType = .no
        baseUrlField.keyboardType = .URL
        baseUrlField.clearButtonMode = .whileEditing
        baseUrlField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(baseUrlField)

        // ---- 步骤按钮 ----
        let steps: [(String, Selector)] = [
            ("1 登录 (test-login)", #selector(stepLogin)),
            ("2 列表 (foods?count=5)", #selector(stepListFoods)),
            ("3 创建 food", #selector(stepCreateFood)),
            ("4 GET 404 (envelope)", #selector(stepGet404)),
            ("5 删除 food (清理)", #selector(stepDeleteFood)),
            ("Run All (5 步)", #selector(runAll)),
            ("清空日志", #selector(clearLog)),
        ]
        var previous: UIView = baseUrlField
        for (title, action) in steps {
            let btn = UIButton(type: .system)
            btn.setTitle(title, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 15)
            btn.layer.cornerRadius = 10
            btn.backgroundColor = .secondarySystemBackground
            btn.addTarget(self, action: action, for: .touchUpInside)
            btn.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(btn)
            stepButtons.append(btn)

            NSLayoutConstraint.activate([
                btn.topAnchor.constraint(equalTo: previous.bottomAnchor, constant: 8),
                btn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
                btn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
                btn.heightAnchor.constraint(equalToConstant: 40),
            ])
            previous = btn
        }

        // ---- 日志区 ----
        logView = UITextView()
        logView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        logView.backgroundColor = .secondarySystemBackground
        logView.layer.cornerRadius = 8
        logView.isEditable = false
        logView.text = "（日志区）"
        logView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logView)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            baseUrlField.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 16),
            baseUrlField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            baseUrlField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            baseUrlField.heightAnchor.constraint(equalToConstant: 36),

            logView.topAnchor.constraint(equalTo: previous.bottomAnchor, constant: 12),
            logView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            logView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            logView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])
    }

    // MARK: - 5 步冒烟（与 H5 版 net_driver / Android SniperYoloAPIActivity 语义一致）

    @objc private func stepLogin() {
        runStep { _ = await self.stepLoginWork() }
    }

    @objc private func stepListFoods() {
        runStep { _ = await self.stepListFoodsWork() }
    }

    @objc private func stepCreateFood() {
        runStep { _ = await self.stepCreateFoodWork() }
    }

    @objc private func stepGet404() {
        runStep { _ = await self.stepGet404Work() }
    }

    @objc private func stepDeleteFood() {
        runStep { _ = await self.stepDeleteFoodWork() }
    }

    @objc private func runAll() {
        runStep {
            guard await self.stepLoginWork() != nil else { return }
            guard await self.stepListFoodsWork() != nil else { return }
            guard await self.stepCreateFoodWork() != nil else { return }
            guard await self.stepGet404Work() != nil else { return }
            _ = await self.stepDeleteFoodWork()
            self.appendLog("—— 全部 5 步完成 ——")
        }
    }

    private func stepLoginWork() async -> HttpResponse? {
        let resp = await exec("POST /users/test-login", "\(base)/users/test-login",
                              RequestOptions(method: .post, connectTimeout: timeoutMs, readTimeout: timeoutMs))
        if case .object(let dict)? = resp?.data, case .string(let s)? = dict["access_token"] {
            token = s
        }
        appendLog(token != nil ? "✓ token 已保存（后续请求自动带 Bearer）" : "⚠ 未取到 access_token")
        return resp
    }

    private func stepListFoodsWork() async -> HttpResponse? {
        await exec("GET /foods/?count=5", "\(base)/foods/",
                   RequestOptions(method: .get, headers: authHeaders(), params: ["count": "5"],
                                  connectTimeout: timeoutMs, readTimeout: timeoutMs))
    }

    private func stepCreateFoodWork() async -> HttpResponse? {
        let body = JSONValue.object([
            "title": .string("native-demo-\(Int(Date().timeIntervalSince1970 * 1000))"),
            "maker": .string("coconut"),
            "star": .number(4),
        ])
        let resp = await exec("POST /foods/", "\(base)/foods/",
                              RequestOptions(method: .post, headers: authHeaders(), body: body,
                                             connectTimeout: timeoutMs, readTimeout: timeoutMs))
        if case .object(let dict)? = resp?.data, let id = dict["id"] {
            createdFoodId = id.serializedString()?.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        appendLog(createdFoodId != nil ? "✓ 已记录新id=\(createdFoodId!)（按钮5可清理）" : "⚠ 未取到新 id")
        return resp
    }

    private func stepGet404Work() async -> HttpResponse? {
        let resp = await exec("GET /foods/99999", "\(base)/foods/99999",
                              RequestOptions(method: .get, headers: authHeaders(),
                                             connectTimeout: timeoutMs, readTimeout: timeoutMs))
        if let resp {
            appendLog(!resp.isSuccess() ? "✓ 404 业务失败 envelope 正常（code=\(resp.code)）" : "✗ 预期业务失败，实际成功了？")
        }
        return resp
    }

    private func stepDeleteFoodWork() async -> HttpResponse? {
        guard let id = createdFoodId else {
            appendLog("跳过：没有待清理的记录（先跑第 3 步创建）")
            return nil
        }
        let resp = await exec("DELETE /foods/\(id)", "\(base)/foods/\(id)",
                              RequestOptions(method: .delete, headers: authHeaders(),
                                             connectTimeout: timeoutMs, readTimeout: timeoutMs))
        if resp?.isSuccess() == true {
            createdFoodId = nil
            appendLog("✓ 已清理 id=\(id)")
        }
        return resp
    }

    // MARK: - 基础设施

    private var base: String {
        (baseUrlField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? defaultBase
            : (baseUrlField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 统一执行 + 日志渲染；传输层失败返回 nil（runAll 借此短路）。
    /// iOS 引擎不 throw —— 网络异常映射为 HttpResponse.error(code=-100x, httpStatus=0)。
    private func exec(_ label: String, _ url: String, _ options: RequestOptions) async -> HttpResponse? {
        appendLog("→ \(label)")
        let resp = await client.request(url, options: options)
        if let code = Int(resp.code), HttpError.isNetworkError(code) {
            appendLog("✗ 网络异常: \(resp.msg)")
            return nil
        }
        appendLog("← HTTP \(resp.httpStatus) · code=\(resp.code) · \(resp.costTime)ms")
        appendLog(pretty(resp.data))
        if !resp.isSuccess() { appendLog("msg: \(resp.msg)") }
        return resp
    }

    private func runStep(_ block: @escaping () async -> Void) {
        view.endEditing(true)
        setStepButtonsEnabled(false)
        Task { @MainActor in
            await block()
            self.setStepButtonsEnabled(true)
        }
    }

    private func authHeaders() -> [String: String] {
        token.map { ["Authorization": "Bearer \($0)"] } ?? [:]
    }

    private func setStepButtonsEnabled(_ enabled: Bool) {
        stepButtons.forEach { $0.isEnabled = enabled; $0.alpha = enabled ? 1 : 0.5 }
    }

    @objc private func clearLog() {
        logView.text = ""
    }

    @objc private func goBack() {
        dismiss(animated: true)
    }

    private func appendLog(_ line: String) {
        if logView.text == "（日志区）" { logView.text = "" }
        logView.text += line + "\n\n"
        let range = NSRange(location: (logView.text as NSString).length - 1, length: 1)
        logView.scrollRangeToVisible(range)
    }

    /// pretty print —— 只对 object/array 走 JSONSerialization（标量会抛
    /// ObjC NSInvalidArgumentException 崩进程，见 memory 踩坑速查）。
    private func pretty(_ value: JSONValue?) -> String {
        guard let value else { return "null" }
        switch value {
        case .object, .array:
            if let obj = value.anyValue(),
               let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
            return value.serializedString() ?? "null"
        default:
            return value.serializedString() ?? "null"
        }
    }
}
