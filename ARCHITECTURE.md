# Coconut 框架架构文档

> **三端（iOS / Android / HarmonyOS NEXT）混合开发框架——H5 通过 JSON-RPC 2.0 调用原生能力。**
> 本文档描述三端模块结构、Bridge 通信、组件注册、安全管线的对照与差异。

---

## 0. 总览

```
┌──────────────────────────────────────────────────────────┐
│              H5 (coconutWebBox / coconut.js)              │
│            CoconutBridge.call('device.getInfo')           │
└────────────────────────┬─────────────────────────────────┘
                         │ JSON-RPC 2.0
                         ▼
┌──────────────┬─────────────────┬────────────────────────┐
│    iOS       │     Android     │      HarmonyOS         │
│  (Swift)     │    (Kotlin)     │      (ArkTS)           │
├──────────────┼─────────────────┼────────────────────────┤
│  Bridge 层   │   Bridge 层     │     Bridge 层           │
│  (async)     │   (sync)        │     (async)            │
├──────────────┼─────────────────┼────────────────────────┤
│ ComponentManager  │ ComponentManager │ ComponentManager │
├──────────────┼─────────────────┼────────────────────────┤
│ App 持有全部组件  │ App 持有全部组件 │ App 持有全部组件     │
└──────────────┴─────────────────┴────────────────────────┘
```

通信协议：JSON-RPC 2.0
- 请求：`{ jsonrpc:'2.0', method:'组件.方法', params:{...}, id, bridgeToken }`
- 响应：`{ jsonrpc:'2.0', id, code:'000000', message, result:'<JSON字符串>' }`

---

## 1. 三端模块结构

### Android

```
AndroidWebBox/
├── coconut-core/        # 核心库（Bridge / Component / Security）
│   └── com/sniper/coconut/
│       ├── bridge/      # CoconutBridge, 安全管线
│       ├── component/   # ComponentManager, BaseComponent, ComponentContext
│       └── utils/
├── coconut-sdk/         # SDK 入口 + WebView 封装（不含组件）
│   └── com/sniper/coconut/
│       ├── CoconutSDK.kt
│       ├── web/         # CoconutWebActivity
│       └── config/
└── app/                 # 宿主 App（持有全部组件源码）
    └── com/sniper/androidwebbox/
        ├── WebBoxApplication.kt   # 在此显式注册组件
        └── components/            # 14 个框架组件 + 业务组件
            ├── device/ network/ storage/ system/ ...
            ├── camera/ mytest/
            └── LoginComponent.kt  # 业务组件示例
```

### iOS

```
iOSWebBox/
├── CoconutSDK/                          # SPM 包（纯框架）
│   └── Sources/CoconutSDK/
│       ├── Bridge/     # CoconutBridge, BridgeSecurityValidator, ...
│       ├── Core/       # ComponentManager, BaseComponent, CoconutPlugin
│       ├── Config/     # CoconutConfig, Environment
│       └── CoconutWebViewController.swift
└── iOSWebBox/                           # 宿主 App
    ├── SceneDelegate.swift              # 在此显式注册组件
    └── Components/                      # 14 个组件（不属于 SPM）
        ├── DeviceComponent.swift
        ├── ClipboardComponent.swift
        └── ...
```

### HarmonyOS

```
HarmonyWebBox/
├── CoconutSDK/                    # HAR：纯框架（不含组件）
│   └── src/main/ets/
│       ├── bridge/                # CoconutBridgeImpl, SecurityValidator, ...
│       ├── component/             # ComponentManager, BaseComponent, CoconutPlugin
│       ├── config/
│       ├── web/                   # CoconutWebPage
│       └── utils/
└── entry/                         # HAP：宿主 App（持有全部组件源码）
    └── src/main/ets/
        ├── entryability/EntryAbility.ets
        ├── pages/Index.ets        # 在此显式注册组件
        └── components/            # 14 个组件（13 通用 + Camera）+ 业务 UI
            ├── DeviceComponent.ets
            ├── ...
            ├── CameraComponent.ets
            └── ui/                # CameraComponent 的 @Builder 弹窗
```

### 模块拆分原则（三端一致）

| 层 | 职责 | Android | iOS | Harmony |
|----|------|---------|-----|---------|
| **框架** | Bridge / 安全 / ComponentManager | coconut-core | CoconutSDK SPM | CoconutSDK HAR |
| **SDK 入口** | 初始化 + WebView 封装 | coconut-sdk | CoconutSDK SPM | CoconutSDK HAR |
| **全部组件** | 框架组件 + 业务组件 | app/ | iOSWebBox/ | entry/ |

> 三端统一：CoconutSDK 只放框架（Bridge / ComponentManager / 安全管线），**不含任何具体组件**。每个集成 CoconutSDK 的工程根据自己业务写组件，App 工程同时持有"通用参考组件"和"业务组件"，通过显式注册决定启用哪些。

---

## 2. Bridge 通信机制

| 项 | iOS | Android | Harmony |
|----|-----|---------|---------|
| **桥协议** | 异步 | 同步 | 异步 |
| **H5 → 原生 API** | `webkit.messageHandlers.CoconutBridge.postMessage()` | `@JavascriptInterface` 注解 `CoconutBridge.call()` | `javaScriptProxy` 注册 `CoconutHarmonyBridge.call()` |
| **原生 → H5 回调** | `webView.evaluateJavaScript()` 调 `window.__coconutIOSCallback(json)` | 同步返回 JSON 字符串 | `webview.runJavaScript()` 调 `window.__coconutHarmonyCallback(json)` |
| **Bridge 主类** | `CoconutBridge` (`WKScriptMessageHandler`) | `CoconutBridgeImpl` (`@JavascriptInterface`) | `CoconutBridgeImpl` (javaScriptProxy) |
| **所在文件** | `CoconutSDK/Bridge/CoconutBridge.swift` | `coconut-core/.../bridge/CoconutBridgeImpl.kt` | `CoconutSDK/.../bridge/CoconutBridgeImpl.ets` |

### 为什么 Android 同步、iOS/Harmony 异步

- **Android WebView** 的 `@JavascriptInterface` 方法**支持同步返回**——JS 调用线程阻塞等结果。简单，但不能处理需要 UI 线程或异步任务的场景（需要 callback 模式）。
- **iOS WKWebView** 的 `postMessage` 是**纯异步**（消息队列），必须用 evaluateJavaScript 主动回写。
- **Harmony Web** 的 `javaScriptProxy` 也是异步（返回 Promise），通过 runJavaScript 回调。

---

## 3. 组件注册流程

三端现在统一为**显式注册**模式（不再扫描注解或硬编码清单）：

```kotlin
// Android WebBoxApplication.kt
CoconutSDK.initialize(this)
CoconutSDK.configure { setDebugMode(true); setEnvironment(DEV) }
CoconutSDK.registerComponents(
    DeviceComponent(), NetworkComponent(), StorageComponent(),
    // ... 共 15 个
)
```

```swift
// iOS SceneDelegate.swift
await CoconutSDK.initialize()
await CoconutSDK.registerComponents([
    DeviceComponent(), NetworkComponent(), StorageComponent(),
    // ... 共 14 个
])
```

```typescript
// Harmony Index.ets
CoconutSDK.registerComponents([
    new DeviceComponent(), new StorageComponent(), new SystemComponent(),
    // ... 共 14 个
])
```

### 注册流程图

```
App 启动
   ↓
CoconutSDK.initialize(context)         # 创建 ComponentContext / ComponentHost
   ↓
CoconutSDK.registerComponents([...])   # 批量注入 ComponentManager
   ↓
ComponentManager 遍历列表
   ↓
对每个组件：
   1. 检查 name 唯一性
   2. 调用 component.initComponent(context)
   3. 触发 onInit(context) 模板方法
   4. 存入内部 Map<String, CoconutPlugin>
   ↓
注册完成，组件就绪等待 Bridge 调用
```

### 关键类对照

| 概念 | Android | iOS | Harmony |
|------|---------|-----|---------|
| **SDK 入口** | `CoconutSDK` (kotlin) | `CoconutSDK` (swift) | `CoconutSDK` (arkts) |
| **组件管理** | `ComponentManager` 单例 | `ComponentManager.shared` | `ComponentManager.getInstance()` |
| **组件基类** | `BaseComponent` (abstract) | `BaseComponent` (open class) | `BaseComponent` (abstract) |
| **组件协议** | `CoconutPlugin` interface | `CoconutPlugin` protocol | `CoconutPlugin` interface |
| **组件上下文** | `ComponentContext` | `ComponentContext` | `ComponentContext` |
| **组件宿主** | `ComponentHost` | `ComponentHost` | `ComponentHost` |
| **存储结构** | `ConcurrentHashMap` | `[String: CoconutPlugin] + NSLock` | `Map<string, CoconutPlugin>` |

### BaseComponent 模板方法

```kotlin
abstract class BaseComponent : CoconutPlugin {
    val name: String                    // 组件唯一标识（如 "device"）
    abstract fun onInit(context)        // 注册时回调，可选重写
    abstract fun handle(function, params): Result  // 必须重写，路由方法
    abstract fun onCleanup()            // 注销时回调
}
```

三端签名一致（语言差异忽略），子类通过 `when/switch` 路由 `function` 字符串到具体方法。

---

## 4. 安全管线

每次 H5 → 原生的调用都经过 3 层校验：

```
H5 发起 call(component.method, params, bridgeToken)
                              │
                              ▼
┌────────────────────────────────────────────────────┐
│ 1. BridgeToken 验证                                 │
│    UUID 会话令牌，注入到 JS 全局变量                  │
│    每次调用必须带上，跟服务端记录比对                  │
├────────────────────────────────────────────────────┤
│ 2. 域名白名单                                       │
│    当前 WebView URL 必须在白名单内                   │
│    防止恶意页面劫持 Bridge                           │
├────────────────────────────────────────────────────┤
│ 3. 限流                                            │
│    按 method 维度计数（默认 100 次/分钟）            │
│    超限拒绝                                         │
└────────────────────────────────────────────────────┘
                              │
                              ▼
                    通过 → 路由到 ComponentManager
                    失败 → 返回对应 ErrorCode
```

### 安全类对照

| 职责 | Android | iOS | Harmony |
|------|---------|-----|---------|
| **BridgeToken** | `BridgeTokenManager.kt` | `BridgeTokenManager.swift` | `BridgeTokenManager.ets` |
| **域名白名单 + 限流** | `BridgeSecurityValidator.kt` | `BridgeSecurityValidator.swift` | `BridgeSecurityValidator.ets` |
| **审计日志** | （内置） | `SecurityAuditLog.swift` | `SecurityAuditLog.ets` |

---

## 5. 一次完整调用的数据流（以 `device.getInfo` 为例）

```
[H5]
  CoconutBridge.call('device.getInfo', {})
      │
      │ 组装请求：
      │ { method:'device.getInfo', params:{}, id:42, bridgeToken:'xxx' }
      ▼
[Bridge 层]（iOS/Harmony 异步；Android 同步）
      │
      ├─ 3 层安全校验（见上节）
      │
      ├─ 解析 method → "device" + "getInfo"
      │
      ├─ ComponentManager.get('device') → DeviceComponent 实例
      │
      └─ DeviceComponent.handle('getInfo', {})
            │
            │ 组装设备信息 → success(map)
            ▼
[Bridge 层]
      │
      │ 包装响应：
      │ { id:42, code:'000000', message:'ok',
      │   result:'{"manufacturer":"Apple",...}' }
      │
      ▼
[H5]
  window.__coconutXxxCallback(json) 触发 Promise resolve
      │
      ▼
  .then(response => { /* 业务拿到设备信息 */ })
```

---

## 6. H5 端（coconut.js）

H5 端通过 `coconutWebBox/` 提供统一的 JS Bridge SDK：

```js
// H5 调用
const result = await CoconutBridge.call('device.getInfo', {});

// 环境检测
CoconutBridge.env.isIOS      // iOS WebView
CoconutBridge.env.isAndroid  // Android WebView
CoconutBridge.env.isHarmony  // Harmony WebView
CoconutBridge.env.isNative   // 任一原生环境
```

`coconut.js` 内部按 `window.webkit.messageHandlers` / `window.AndroidBridge` / `window.CoconutHarmonyBridge` 判断当前平台，路由到对应 Bridge。

详细 API 见 `coconutWebBox/README.md` 和 `API_CONTRACT.md`。

---

## 7. 关键 API 签名对照

### 初始化

| 平台 | 签名 |
|------|------|
| Android | `CoconutSDK.initialize(context: Context)` |
| iOS | `await CoconutSDK.initialize()` |
| Harmony | `CoconutSDK.initialize(context: UIAbilityContext)` |

### 配置

| 平台 | 签名 |
|------|------|
| Android | `CoconutSDK.configure { setDebugMode(true); setEnvironment(DEV) }` |
| iOS | `CoconutSDK.configure { $0.debugMode = true; $0.environment = .dev }` |
| Harmony | `CoconutSDK.configure { it.debugMode = true; it.environment = Environment.DEV }` |

### 注册组件

| 平台 | 签名 |
|------|------|
| Android | `suspend fun registerComponents(vararg c: BaseComponent)` |
| iOS | `static func registerComponents(_ c: [CoconutPlugin]) async` |
| Harmony | `static async registerComponents(c: CoconutPlugin[]): Promise<void>` |

---

## 8. 错误码命名空间

| 段 | 含义 | 示例 |
|----|------|------|
| `000000` | 成功 | `SUCCESS` |
| `100001-100005` | 协议层错误 | `PARSE_ERROR`, `METHOD_NOT_FOUND`, `INVALID_PARAMS`, `INTERNAL_ERROR` |
| `200001-200009` | 业务错误 | `UNKNOWN_COMPONENT`, `UNKNOWN_FUNCTION`, `PERMISSION_DENIED`, `TIMEOUT`, `PARAM_VALIDATION_FAILED`, `RATE_LIMIT_EXCEEDED` |
| `300004` | 安全错误 | `BRIDGE_TOKEN_INVALID` |

三端 `ErrorCode` 常量定义一致，详见 `API_CONTRACT.md`。

---

## 9. 相关文档

- [`API_CONTRACT.md`](./API_CONTRACT.md) — 三端 API 契约（组件方法签名、错误码、安全机制）
- [`coconutWebBox/README.md`](./coconutWebBox/README.md) — H5 端 JS Bridge 用法
- [`AndroidWebBox/COCONUT_SDK_INTEGRATION.md`](./AndroidWebBox/COCONUT_SDK_INTEGRATION.md) — Android SDK 集成指南

---

## 10. 设计原则

1. **三端对齐**：API 签名、错误码、安全机制三端必须一致（详见 `API_CONTRACT.md`）
2. **SDK 纯净**：框架只放 Bridge / 安全 / ComponentManager；组件归 App 装配
3. **显式注册**：不扫描注解、不硬编码清单；App 决定启用哪些组件
4. **安全分层**：BridgeToken / 白名单 / 限流 可独立开关
5. **业务无关**：CoconutSDK 不含任何业务组件（如 Login），业务组件由 App 自带
