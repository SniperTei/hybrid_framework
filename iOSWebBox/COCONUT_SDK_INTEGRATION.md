# Coconut SDK 集成指南（iOS）

> 面向要在**自己的 iOS App** 里接入 CoconutSDK 的开发者。框架内部结构见 [`CoconutSDK/README.md`](./CoconutSDK/README.md)，三端 API 契约见仓库根 [`API_CONTRACT.md`](../API_CONTRACT.md)（唯一权威）。
>
> 参考实现：`iOSWebBox/`（宿主 demo，持有 6 个组件 + 模板容器 + 热更新入口）。

---

## 1. 集成 CoconutSDK

CoconutSDK 是本地 SPM 包（`iOSWebBox/CoconutSDK/`），依赖独立 HTTP 引擎包 CoconutNetwork（`iOSWebBox/CoconutNetwork/`，纯 Foundation 零第三方依赖）。两种方式：

### 方式 1：SPM 包引用（推荐）

把 `CoconutSDK/` 和 `CoconutNetwork/` 两个目录拷进你的工程（如 `Vendor/` 下），拖入 workspace，在你的主 target 的 **General → Frameworks, Libraries, and Embedded Content** 里加 `CoconutSDK`。CoconutNetwork 由 CoconutSDK 的 Package.swift 自动带出，无需单独配置。

### 方式 2：源文件拷贝

把 `CoconutSDK/Sources/CoconutSDK/*.swift` 复制进主 target（保留目录结构有助维护）。此方式需一并处理 CoconutNetwork 的引用（NetworkComponent 依赖它；不用 network 组件可不引）。

> **组件不在 SDK 内**。框架只含 Bridge / ComponentManager / 安全管线 / 容器，所有组件（DeviceComponent / ...）都在宿主 App（见 `iOSWebBox/Components/`），由 App 显式注册决定启用哪些。

## 2. 初始化（SceneDelegate / AppDelegate）

推荐时序：**configure → initialize → registerComponents → 再加载任何 H5 页面**（bridge 就绪必须先于页面第一次 call，demo 的 SceneDelegate.swift 就是这个顺序）：

```swift
import CoconutSDK

// 1. 配置（同步，最早调）
CoconutSDK.configure { config in
    config.debugMode = true
    config.environment = .dev          // .dev / .staging / .prod
    config.enableBridgeToken = true    // 默认 true；3 层安全均可独立开关
    // config.allowedDomains = ["example.com"]   // 域名白名单；空 = 放行所有（demo 友好，生产建议收紧）
}

// 2. 初始化 + 显式注册组件（异步；组件是宿主 App 的类）
Task {
    await CoconutSDK.initialize()
    await CoconutSDK.registerComponents([
        DeviceComponent(),
        StorageComponent(),
        EventComponent(),
        DialogComponent(),
        NetworkComponent(),
        NavigatorComponent(),
        // + 业务组件按需
    ])

    await MainActor.run {
        // 这里再设置 rootViewController / present 容器
    }
}

// 3. 清理（App 退出 / 用户登出）
// await CoconutSDK.cleanup()
```

## 3. 打开 WebView 容器

### 现成容器：`CoconutWebViewController`

```swift
let vc = CoconutWebViewController()
vc.enableDebug = true
vc.modalPresentationStyle = .fullScreen       // 容器按全屏 modal 设计
present(vc, animated: true) {
    vc.loadUrl("https://example.com")         // 或 coconut://demo/index.html（离线包）
}
```

v3.5.0 起容器自带：自绘导航栏（NavConfig 三级合并）、白屏错误弹窗（重试/退出，过滤 `NSURLErrorCancelled`，HTTP 4xx/5xx 不弹）、多容器 resume-claim。**返回语义一条路**：导航栏返回 = `canGoBack ? goBack : dismiss`。

⚠️ **集成到已有导航栈的 App**：容器当前按 fullScreen modal 链设计（无 UINavigationController 绑定）。嵌入 nav stack 需要：
- push 的话自绘导航栏仍可用（不与 UINavigationBar 冲突），但「返回退化 dismiss」语义要覆写 delegate 钩子 `onBack() -> Bool` 拦截
- 或继承 `CoconutWebViewController` 做模板容器（见 §4）

### 自定义容器（用自己的 WKWebView）

不用的现成 VC 也行：`CoconutSDK.initialize` + 把 message handler 注册到自己的 WKWebView（`CoconutBridge` 是 `WKScriptMessageHandler`，注入 `coconut.js` 后 H5 即可调用）。参考 `CoconutWebViewController.swift` 的装配代码。

## 4. 模板容器（业务定制页）

继承 `CoconutWebViewController` + 注册到 `coconut_templates.json`（bundle resource）：

```json
[ { "templateName": "demo", "templatePage": "你的模块名.DemoTemplateViewController" } ]
```

```swift
class DemoTemplateViewController: CoconutWebViewController {
    // 加宿主自定义 UI / 覆写 delegate 钩子（onBack 拦截 / onLoadFail / onTitleChange）
}
```

H5 侧 `coconut.navigator.forward({ url, template: 'demo' })` 即命中。**类名必须带模块前缀**（`NSClassFromString` 裸类名静默返回 nil）；启动期建议跑 `try TemplateRegistry.shared.validateEagerly()` fail-fast（demo SceneDelegate 有示范）。

## 5. 写一个自定义组件

```swift
import CoconutSDK

public class EchoComponent: BaseComponent {
    public override var name: String { "echo" }
    public override var version: String { "1.0.0" }

    public override func handle(_ function: String, paramsJson: String) async throws -> BridgeResponse {
        switch function {
        case "ping":
            let msg = getParam(paramsJson, "message", defaultValue: "pong")  // BaseComponent helper
            return .success(result: ["echo": msg])
        default:
            throw ComponentException.functionNotFound(function)
        }
    }
}
```

注册进 `CoconutSDK.registerComponents([...])` 后，H5 调用：

```js
coconut.call('echo', 'ping', { message: 'hi' }, (err, data) => {
    if (err) { console.error(err.code, err.message); return; }
    console.log(data);   // { echo: 'hi' }
});
```

## 6. 离线包 / 热更新 / Network

- **离线包**：`coconut://<moduleId>/<path>`，`CoconutSchemeHandler`（WKURLSchemeHandler）本地服务，vite 产物必须 **iife + classic script**（ES module 在自定义 scheme 的 null origin 必被 CORS 拦，详见仓库根 `ARCHITECTURE.md` §7）
- **热更新**：`CoconutUpdateManager.shared.checkUpdate / performUpdate / rollback`，下载走 CoconutNetwork 引擎（重试 / SSRF 守卫 / 统一超时自动生效）
- **Network**：`NetworkComponent` 桥接 CoconutNetwork 引擎，H5 `coconut.call('network', 'request' | 'getNetworkType', ...)`；native 侧也可直接用引擎一发式 API（`client.get/post/...`，参考 `SniperYoloAPIViewController.swift`）

## 7. Info.plist 注意事项

- **ATS**：iOS 拦非 localhost 明文 HTTP（URLSession 层）。localhost 开发服务器（如 Vite dev server）配 `NSAllowsLocalNetworking` 即够；要直连明文 HTTP 服务且地址是 **IP 字面量**时 `NSExceptionDomains` 不生效，只能 `NSAllowsArbitraryLoads`（demo 的做法，生产按域名配例外）
- demo e2e 钩子（`COCONUT_URL` / `COCONUT_UPDATE_URL` / `SNIPER_API_BASE` 等 env）仅调试构建使用，生产不设即可

## 8. 测试与验证

```bash
cd iOSWebBox/CoconutSDK
xcodebuild test -scheme CoconutSDK -destination 'id=<模拟器UDID>'   # 128 case（需模拟器；macOS 宿主 swift test 不行）
cd ../CoconutNetwork && swift test                                   # 64 case（纯 Foundation，宿主直跑）
```

## 9. iOS 踩坑速查（真金换来的）

| 坑 | 正解 |
|----|------|
| SourceKit 报 `No such module 'UIKit'` | macOS host 误报，验证以 `xcodebuild build` 为准 |
| `NSString.deletingLastPathComponent` 拼 URL | 路径语义会把 `http://` 折成 `http:/`，手动切 last `/` |
| `JSONSerialization` 对标量 `NSNumber` | `isValidJSONObject` 返回 true 但 `data(withJSONObject:)` 抛 ObjC 异常**崩进程**，只对 `[String: Any]` / `[Any]` 调 |
| Swift 6.2 同步测试方法里创建局部 `@MainActor` 对象 | 触发 back-deployed deinit malloc bug（SIGABRT），复用 setUp 的 ivar |
| coconut.js 走离线包被 CORS 拦 | vite 构建 iife + classic script，不用 ES module |

组件/方法签名以 [`API_CONTRACT.md`](../API_CONTRACT.md) 为准；H5 侧可用 `coconut.supports(component, fn)` 探测宿主能力。
