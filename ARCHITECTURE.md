# Coconut 框架架构文档

> **三端（iOS / Android / HarmonyOS NEXT）混合开发框架——H5 通过 JSON-RPC 2.0 调用原生能力。**
> 本文档描述三端模块结构、Bridge 通信、组件注册、安全管线的对照与差异。

---

## 0. 总览

```
┌──────────────────────────────────────────────────────────┐
│              H5 (coconutWebBox / coconut.js)              │
│        coconut.call('device', 'getInfo', params, cb)      │
└────────────────────────┬─────────────────────────────────┘
                         │ 类 JSON-RPC（v3 wire 协议）
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

通信协议：类 JSON-RPC（无版本字段，主版本号 = `coconut.env.hybridVersion` = `"3"`；v3.1.0 起 `method` 拆成顶级 `component` + `function` 两个字段）
- 请求：`{ component:'storage', function:'setItem', params:{...}, id, bridgeToken }`
- 响应：`{ id, code:'000000', message, result:'<JSON字符串或对象>' }`（流式响应带 `streaming:true`，详见 `API_CONTRACT.md` §0）

---

## 1. 三端模块结构

### Android

```
AndroidWebBox/
├── coconut-core/        # 核心库（Bridge / Component / Security）
│   └── com/sniper/coconut/
│       ├── bridge/      # CoconutBridge, 安全管线
│       ├── component/   # ComponentManager, BaseComponent, ComponentContext
│       ├── resource/    # OfflineResourceManager（离线包 + 热更新）
│       └── utils/
├── coconut-network/     # 独立网络引擎（纯 Kotlin JVM 库，零 Android 依赖）
│   └── com/sniper/coconut/network/
│       ├── HttpClient / Call / HttpRequest / HttpResponse
│       ├── adapter/     # HttpURLConnectionAdapter（默认）+ OkHttpAdapter
│       ├── guard/       # UrlGuard（SSRF 防护）
│       └── interceptors/  # Log / Mock
├── coconut-sdk/         # SDK 入口 + WebView 封装（不含组件）
│   └── com/sniper/coconut/
│       ├── CoconutSDK.kt
│       ├── web/         # CoconutWebActivity
│       └── config/
└── app/                 # 宿主 App（持有全部组件源码）
    └── com/sniper/androidwebbox/
        ├── WebBoxApplication.kt   # 在此显式注册组件
        └── components/            # 5 个组件：device / storage / event / dialog / network
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
    └── Components/                      # 4 个组件（不属于 SPM；network 未落地）
        ├── DeviceComponent.swift
        ├── StorageComponent.swift
        ├── EventComponent.swift
        └── DialogComponent.swift
```

### HarmonyOS

```
HarmonyWebBox/
├── CoconutSDK/                    # HAR：纯框架（不含组件）
│   └── src/main/ets/
│       ├── bridge/                # CoconutBridgeImpl, SecurityValidator, ...
│       ├── component/             # ComponentManager, BaseComponent, CoconutPlugin
│       ├── config/
│       ├── web/                   # CoconutWebPage, CoconutUpdateManager（热更新）
│       └── utils/
├── CoconutNetwork/                # 独立网络引擎 HAR @coconut/network（零依赖）
│   └── src/main/ets/
│       ├── HttpClient / Call / HttpRequest / HttpResponse
│       ├── adapter/               # HarmonyHttpAdapter（默认），可插拔
│       ├── guard/                 # UrlGuard（SSRF 防护）
│       └── interceptors/          # Log / Mock
└── entry/                         # HAP：宿主 App（持有全部组件源码）
    └── src/main/ets/
        ├── entryability/EntryAbility.ets
        ├── pages/Index.ets        # 在此显式注册组件
        └── components/            # 5 个组件：device / storage / event / dialog / network
```

### 模块拆分原则（三端一致）

| 层 | 职责 | Android | iOS | Harmony |
|----|------|---------|-----|---------|
| **框架** | Bridge / 安全 / ComponentManager | coconut-core | CoconutSDK SPM | CoconutSDK HAR |
| **SDK 入口** | 初始化 + WebView 封装 | coconut-sdk | CoconutSDK SPM | CoconutSDK HAR |
| **独立引擎库** | 可脱离 SDK 复用的领域能力（如网络） | coconut-network（Kotlin JVM） | ❌ 未落地 | CoconutNetwork HAR |
| **全部组件** | 框架组件 + 业务组件 | app/ | iOSWebBox/ | entry/ |

> 三端统一：CoconutSDK 只放框架（Bridge / ComponentManager / 安全管线），**不含任何具体组件**。每个集成 CoconutSDK 的工程根据自己业务写组件，App 工程同时持有"通用参考组件"和"业务组件"，通过显式注册决定启用哪些。
>
> 独立引擎库（先例：CoconutNetwork）不依赖 CoconutSDK，纯 native 项目可直接集成；组件层（如 NetworkComponent）负责把它桥接到 H5 bridge。

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
    DeviceComponent(),      // 设备信息
    StorageComponent(),     // 本地存储
    EventComponent(),       // 事件订阅
    DialogComponent(),      // 原生弹窗
    NetworkComponent()      // 网络请求 + 状态推送
)
```

```swift
// iOS SceneDelegate.swift
await CoconutSDK.initialize()
await CoconutSDK.registerComponents([
    DeviceComponent(),
    StorageComponent(),
    EventComponent(),
    DialogComponent(),
    // NetworkComponent 未落地（组件矩阵见 API_CONTRACT.md §1）
])
```

```typescript
// Harmony Index.ets
CoconutSDK.registerComponents([
  new DeviceComponent(),
  new StorageComponent(),
  new EventComponent(),
  new DialogComponent(),
  new NetworkComponent()
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
  coconut.call('device', 'getInfo', {}, cb)
      │
      │ 组装请求：
      │ { component:'device', function:'getInfo', params:{}, id:42, bridgeToken:'xxx' }
      ▼
[Bridge 层]（iOS/Harmony 异步；Android 同步）
      │
      ├─ 3 层安全校验（见上节）
      │
      ├─ 读顶级 component/function 字段路由（v3.1.0 起拆分）
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
  iOS: window.__coconutIOSCallback(json)（evaluateJavaScript 回写）
  Harmony: window.__coconutHarmonyCallback(json)（runJavaScript 回写）
  Android: @JavascriptInterface 同步返回值直接拿到
      │
      ▼
  cb(err, data)   ← coconut.js error-first callback，err=null 时 data 为 result 对象
```

---

## 6. H5 端（coconut.js）

H5 端通过 `coconutWebBox/` 提供统一的 JS Bridge SDK（`coconut.js`，UMD 单例，全局挂载小写 `window.coconut`，v3.0.0 起）：

```js
// H5 调用（error-first callback）
coconut.call('device', 'getInfo', {}, (err, data) => {
  if (err) { /* err = { code:'200007', message:'...' } */ }
  else    { /* data = result 对象 */ }
});

// 环境检测
coconut.env.isiOS      // iOS WebView
coconut.env.isAndroid  // Android WebView
coconut.env.isHarmony  // Harmony WebView
coconut.env.isNative   // 任一原生环境
coconut.env.hybridVersion  // bridge 协议主版本 '3'（lazy：appName/appVersion/capabilities 同）

// 能力探测（组件方法是否在当前平台落地）
coconut.supports('network', 'request')  // true / false

// 生命周期（零 native 代码，visibilitychange 派生）
coconut.on('app.foreground', cb); coconut.on('app.background', cb);
```

`coconut.js` 内部按 `window.CoconutBridge`（Android）/ `window.webkit.messageHandlers.CoconutBridge`（iOS）/ `window.CoconutHarmonyBridge`（Harmony）判断当前平台，路由到对应 Bridge。

详细 API 见 `coconutWebBox/README.md` 和 `API_CONTRACT.md`。

---

## 7. 离线包（coconut://）

H5 构建产物打包进 App 本地服务，统一入口 `coconut://<moduleId>/<path>`（如 `coconut://demo/index.html`）。不依赖网络 / dev server / 局域网 IP。

### 目录布局与构建

```bash
bash scripts/build-offline-package.sh          # 构建 + 分发三端
bash scripts/build-offline-package.sh --check  # CI 校验三端一致性（drift exit 1）
```

构建产物（`coconutWebBox` vite build，**iife 格式 + classic script**）+ 生成的 `manifest.json`，全量重建分发到三端：

| 平台 | 内置包位置 | 沙箱覆盖层（热更新预留） |
|------|-----------|------------------------|
| Android | `app/src/main/assets/coconut-web/<moduleId>/` | `filesDir/coconut_resources/<moduleId>/` |
| iOS | SPM resource `CoconutSDK/.../Resources/coconut-web/<moduleId>/` | `Application Support/CoconutResources/<moduleId>/` |
| Harmony | `entry/src/main/resources/rawfile/coconut-web/<moduleId>/` | `filesDir/coconut_resources/<moduleId>/` |

`manifest.json`（Android `OfflineResourceManager` 解析器的超集）：

```json
{
  "moduleId": "demo",
  "version": "1.0.0",
  "entry": "index.html",
  "files": ["index.html", "assets/index.js", "..."],
  "md5": "<全部文件 md5 拼接后的 md5>",
  "fileHashes": { "index.html": "…" }
}
```

### 三端服务机制

查找顺序三端一致：**沙箱覆盖层 → 内置包 → 404**（为热更新铺路）。

- **Android**：`CoconutWebActivity.loadUrl()` 把 `coconut://` 翻译成虚拟域 `https://coconut.local/coconut-web/…`，主帧 + 子资源全走 `shouldInterceptRequest` 拦截 → `OfflineResourceManager`（沙箱 > assets）。⚠️ 不能用 `file:///android_asset/…`：Chromium 对 `file:` scheme **不触发** `shouldInterceptRequest`（[issues.chromium.org/issues/40419811](https://issues.chromium.org/issues/40419811)），沙箱覆盖层会静默失效（内置包仍能加载，纯靠 WebView 原生 file 支持，具有迷惑性）。
- **iOS**：`CoconutSchemeHandler`（`WKURLSchemeHandler`，注册 `coconut` scheme）。主帧 + 子资源全走 handler，无需翻译。in-flight task Set 守卫 `stop()` 后回调 crash。
- **Harmony**：ArkWeb 无自定义 scheme 注册。`CoconutWebPage` 把主帧 `coconut://` 翻译成 `resource://rawfile/coconut-web/…`（内置 load 路径），`onInterceptRequest` 对两种 URL 形态做沙箱 > rawfile 服务（`CoconutOfflineResources`）。返回 null = 不拦截普通 http(s)。

> **已知 scheme 偏差**：Harmony 主帧实际加载的是翻译后的 `resource://rawfile/…` URL（H5 里 `location.href` 可见）；Android 同理（`https://coconut.local/…`）。仅 iOS 主帧保持 `coconut://` 原样。Android 虚拟域是 https origin —— 若 App 启用了域名白名单，需把 `coconut.local` 加入白名单。

### 关键约束：module script 与 null origin

ES module `<script type="module">` 规范上**永远走 CORS 模式请求**，而 `file://` / `resource://` 等离线 scheme 的 origin 是 `null` → 必被 CORS 拦截（与 `crossorigin` 属性无关）。因此构建管线强制 **rollup `format: 'iife'`**（CSS 转 JS 注入）+ 剥掉 vite 仍写入的 `type="module"` / `crossorigin` 属性（`build-offline-package.sh` 内 sed）。新增离线包入口时勿改回 ES module 输出。

### 热更新（逐文件下载 + 原子切换 + 回滚）

三端管理器语义一致：Android `OfflineResourceManager`（coconut-core）、iOS `CoconutUpdateManager.swift`、Harmony `CoconutUpdateManager.ets`。触发方式为 native demo 按钮（检查更新 / 回滚），暂无 H5 bridge 组件、无进度回调。

**版本持久化**：`<沙箱根>/version.json` = `{"<moduleId>": "<version>"}`。当前版本 = max(沙箱 version.json, 内置包 manifest version)，缺失视为 0.0.0。

**checkUpdate(moduleId, manifestUrl)**：GET manifest → 解析 → `available = compareVersions(remote, current) > 0`。manifest 解析宽容（未知字段忽略、pretty-print 容忍）；网络/解析失败返回 `error`，不抛异常。

**performUpdate(manifest, baseUrl)**：
1. 校验：files 非空；每个文件必须有 fileHashes 条目（缺失即拒，fail-closed）；路径过 `isSafePackagePath`（拒 `..` 段 / 前导 `/` / `\` / 空段）
2. 逐文件：下载 → md5 比对（小写 hex）→ 匹配写 `.staging_<moduleId>/`；任何失败 → 递归删 staging 返回失败，**旧版本原封不动**
3. 全过 → 原子切换：删模块目录 → rename staging → 写 version.json

**rollback(moduleId)**：递归删沙箱模块目录 + 删 version.json 条目 → 回落内置包。

**e2e fixture**：`scripts/serve-hot-update.sh` 拷内置 demo 包 → bump 1.0.1 + 注入 `<div>HOT UPDATE v1.0.1</div>` marker + 重算哈希，`python3 -m http.server 8000`。flags：`--corrupt`（篡改 index.html 哈希供失败路径验证）/ `--quiet`。注意模拟器网络：Android 用 `10.0.2.2`、iOS sim 用 `localhost`、Harmony 必须用 Mac 局域网 IP。

**平台注记**：
- Harmony `fileIo.mkdirSync` 在目标已存在时抛 "File exists"（recursive=true 也一样）——所有建目录走守卫过的 `ensureDir`
- Harmony `cryptoFramework` MD5 在部分模拟器镜像上 HUKS 层失败 → 纯 JS RFC 1321 实现（已知向量测试钉死正确性）
- Android rollback 后重建内存版本 map（内置版本 re-merge）

---

## 8. 关键 API 签名对照

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

## 9. 错误码命名空间

| 段 | 含义 | 示例 |
|----|------|------|
| `000000` | 成功 | `SUCCESS` |
| `100001-100005` | 协议层错误 | `PARSE_ERROR`, `METHOD_NOT_FOUND`, `INVALID_PARAMS`, `INTERNAL_ERROR` |
| `200001-200007` | 业务错误 | `UNKNOWN_COMPONENT`, `UNKNOWN_FUNCTION`, `PERMISSION_DENIED`, `RATE_LIMIT_EXCEEDED`, `PARAM_VALIDATION_FAILED` |
| `300004` | 安全错误 | `BRIDGE_TOKEN_INVALID` |

三端 `ErrorCode` 常量定义一致，详见 `API_CONTRACT.md`。

---

## 10. 相关文档

- [`API_CONTRACT.md`](./API_CONTRACT.md) — 三端 API 契约（组件方法签名、错误码、安全机制）
- [`coconutWebBox/README.md`](./coconutWebBox/README.md) — H5 端 JS Bridge 用法
- [`AndroidWebBox/COCONUT_SDK_INTEGRATION.md`](./AndroidWebBox/COCONUT_SDK_INTEGRATION.md) — Android SDK 集成指南

---

## 11. 设计原则

1. **三端对齐**：API 签名、错误码、安全机制三端必须一致（详见 `API_CONTRACT.md`）
2. **SDK 纯净**：框架只放 Bridge / 安全 / ComponentManager；组件归 App 装配
3. **显式注册**：不扫描注解、不硬编码清单；App 决定启用哪些组件
4. **安全分层**：BridgeToken / 白名单 / 限流 可独立开关
5. **业务无关**：CoconutSDK 不含任何业务组件（如 Login），业务组件由 App 自带
