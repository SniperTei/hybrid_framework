# CoconutSDK (iOS)

> iOS 端 CoconutSDK —— Swift Package，封装 WebView + JSON-RPC Bridge + 组件管理 + 安全管线。
> 最低支持 iOS 15。使用 `WKWebView`。

跨平台架构、Bridge 协议、错误码、安全机制详见仓库根 [`ARCHITECTURE.md`](../../ARCHITECTURE.md) 和 [`API_CONTRACT.md`](../../API_CONTRACT.md)。本 README 只介绍 iOS 端的结构、API、用法。

---

## 模块结构

```
CoconutSDK/                         # SPM 包根
├── Package.swift                   # Swift 6.0 / iOS 15+
├── Sources/CoconutSDK/
│   ├── CoconutWebViewController.swift   # 顶层 VC：WKWebView + CoconutSDK 装配
│   │
│   ├── Config/
│   │   ├── CoconutConfig.swift          # SDK 入口（静态 initialize / configure / registerComponents）
│   │   └── Environment.swift            # DEV / STAGING / PROD
│   │
│   ├── Core/                            # 组件系统
│   │   ├── CoconutPlugin.swift          # 组件协议（name / version / handle）
│   │   ├── BaseComponent.swift          # 抽象基类（含 init/cleanup 模板方法 + param helpers）
│   │   ├── ComponentContext.swift       # 上下文（ViewController / Logger / 资源）
│   │   ├── ComponentHost.swift          # 组件宿主
│   │   ├── ComponentManager.swift       # 单例：注册、路由、生命周期
│   │   └── Logger.swift                 # 统一日志（OSLog / 闭包注入）
│   │
│   ├── Bridge/                          # JSON-RPC Bridge + 安全管线
│   │   ├── CoconutBridge.swift          # 主类：WKScriptMessageHandler
│   │   ├── BridgeDispatcher.swift       # 请求分发 + 5 层安全校验
│   │   ├── BridgeResponse.swift         # 响应封装
│   │   ├── BridgeResponseSender.swift   # evaluateJavaScript 回调 H5
│   │   ├── BridgePerformance.swift      # 调用耗时统计
│   │   ├── BridgeSecurityValidator.swift# 域名白名单 + 限流 + params 大小
│   │   ├── BridgeTokenManager.swift     # UUID 会话令牌
│   │   ├── RequestSignatureValidator.swift # HMAC-SHA256（CryptoKit）
│   │   ├── SecurityAuditLog.swift       # 安全事件审计
│   │   ├── ComponentException.swift     # 组件异常类型
│   │   └── ErrorCode.swift              # 错误码命名空间
│   │
│   └── (待补充)
│
└── Tests/CoconutSDKTests/               # 74 个 XCTest case
    ├── BridgeTokenManagerTests.swift
    ├── RequestSignatureValidatorTests.swift
    ├── BridgeSecurityValidatorTests.swift
    ├── BridgePerformanceTests.swift
    ├── SecurityAuditLogTests.swift
    ├── BridgeRequestTests.swift
    ├── BridgeResponseTests.swift
    ├── ErrorCodeTests.swift
    ├── BaseComponentTests.swift
    ├── ComponentManagerTests.swift
    ├── ComponentExceptionTests.swift
    ├── EnvironmentTests.swift
    ├── JsonHelperTests.swift
    └── BridgeDispatcherTests.swift
```

> **组件不在 SPM 内**。框架不含任何业务组件，所有组件（DeviceComponent / NetworkComponent / ...）都在宿主 App `iOSWebBox/Components/` 下，App 决定启用哪些。

---

## 核心 API

### `CoconutSDK`（静态入口）

```swift
// 1. 初始化（异步，通常在 SceneDelegate 里 await）
await CoconutSDK.initialize()

// 2. 配置
CoconutSDK.configure {
    $0.debugMode = true
    $0.environment = .dev
    $0.enableBridgeToken = true      // 默认 true
    $0.enableRequestSigning = false  // 默认 false
    $0.allowedDomains = ["example.com"]
}

// 3. 注册组件（显式，不扫描注解）
await CoconutSDK.registerComponents([
    DeviceComponent(),
    NetworkComponent(),
    StorageComponent(),
    // ... 共 14 个
])

// 4. 清理（App 退出 / 用户登出时）
await CoconutSDK.cleanup()
```

### `CoconutWebViewController`

封装好的顶层 VC：内部创建 WKWebView、注入 coconut.js、注册 CoconutBridge message handler、加载初始 URL。

```swift
let vc = CoconutWebViewController(url: URL(string: "https://example.com")!)
navigationController?.pushViewController(vc, animated: true)
```

也可以**不用这个 VC**——如果你有自己的 WebView 容器，直接调 `CoconutSDK.initialize` + 把 message handler 注册到自己的 WKWebView。

---

## 写一个自定义组件

```swift
import CoconutSDK

public class EchoComponent: BaseComponent {
    public override var name: String { "echo" }
    public override var version: String { "1.0.0" }

    public override func handle(
        _ function: String,
        paramsJson: String
    ) async throws -> BridgeResponse {
        switch function {
        case "ping":
            // getParam / getIntParam / getBoolParam 是 BaseComponent 的 helper
            let msg = getParam(paramsJson, "message", defaultValue: "pong")
            return .success(result: ["echo": msg])
        default:
            throw ComponentException.functionNotFound(function)
        }
    }
}
```

注册到 `CoconutSDK.registerComponents([..., EchoComponent()])` 之后，H5 就能调用：
```js
const r = await CoconutBridge.call('echo.ping', { message: 'hi' });
// r.result === { echo: 'hi' }
```

---

## Bridge 模式（iOS 异步）

iOS 的 `WKWebView` 的 `postMessage` 是**纯异步**的（消息队列），无法像 Android 那样同步返回。所以 iOS Bridge 走：

```
H5: webkit.messageHandlers.CoconutBridge.postMessage(jsonRpcRequest)
   ↓
CoconutBridge.userContentController(... didReceive message:)
   ↓
BridgeDispatcher：5 层安全校验 → ComponentManager 路由 → 组件 handle
   ↓
BridgeResponseSender: webView.evaluateJavaScript(
    "window.__coconutIOSCallback(\(jsonResponse))"
)
   ↓
H5: Promise resolve
```

---

## 测试

```bash
cd iOSWebBox/CoconutSDK
xcodebuild test -scheme CoconutSDK \
    -destination 'id=2493097D-3EC4-48C3-8E4D-7C164A11E568'
# 74 个 case，~0.3s
```

测试覆盖：Bridge 模型 / 安全管线（Token / Signature / Security / Audit / Performance） / Component 系统 / Config / Logger。**不覆盖** `CoconutWebViewController`（需要 WKWebView 实例，属于 UI 测试范畴）。

---

## 集成到自己的 iOS App

CoconutSDK 是本地 SPM 包。两种方式：

### 方式 1：直接拷贝目录

把 `CoconutSDK/` 整个目录拷贝到你的项目，作为子模块加入你的 Xcode workspace，在主 target 的 Frameworks / Libraries / Embedded Content 里加 `CoconutSDK.xcodeproj`。

### 方式 2：复制源文件到主 target

如果不想用 SPM，直接把 `Sources/CoconutSDK/*.swift` 复制到你的项目里。注意要保留目录结构（Swift 不强制，但有助于维护）。

集成完后，按"核心 API"那一节的 4 步调用。
