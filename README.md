# Coconut Hybrid Framework

> 三端（iOS / Android / HarmonyOS NEXT）混合开发框架——H5 通过 JSON-RPC 2.0 调用原生能力。

一个 WebView 容器 + JS Bridge 框架。H5 用同一套 API（`CoconutBridge.call('device.getInfo')`）调用三端的设备能力、网络、存储、UI 组件等。三端 CoconutSDK 接口、安全管线、错误码完全对齐。

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
│  CoconutSDK  │  coconut-core / │     CoconutSDK         │
│   (SPM)      │  coconut-sdk    │       (HAR)            │
└──────────────┴─────────────────┴────────────────────────┘
```

---

## 仓库结构

```
hybrid_framework/
├── coconutWebBox/         # H5 SDK：coconut.js（JS Bridge 客户端）
├── iOSWebBox/             # iOS 宿主 App + CoconutSDK SPM 包
│   ├── CoconutSDK/        # SPM 包（框架）
│   └── iOSWebBox/         # 宿主 App（持有 4 个组件：device / storage / event / dialog）
├── AndroidWebBox/         # Android 宿主 App + CoconutSDK Gradle 模块
│   ├── coconut-core/      # 核心库（Bridge / Component / Security）
│   ├── coconut-sdk/       # SDK 入口 + WebView 封装
│   ├── coconut-network/   # 独立 HTTP 引擎（纯 Kotlin JVM 库，零 Android 依赖，可单独使用）
│   └── app/               # 宿主 App（持有 5 个组件：device / storage / event / dialog / network）
├── HarmonyWebBox/         # HarmonyOS 宿主 App + CoconutSDK HAR
│   ├── CoconutSDK/        # HAR 库（框架）
│   ├── CoconutNetwork/    # 独立 HTTP 引擎 HAR（@coconut/network，零依赖，可单独使用）
│   └── entry/             # HAP 宿主 App（持有 5 个组件：device / storage / event / dialog / network）
├── ARCHITECTURE.md        # 三端架构对照（详细模块图 / Bridge / 安全管线）
└── API_CONTRACT.md        # 三端 API 契约（组件方法签名、错误码、安全机制）
```

**模块拆分原则（三端一致）**：CoconutSDK 只放框架（Bridge / ComponentManager / 安全管线），**不含任何具体组件**。组件归 App 装配。每个集成 CoconutSDK 的工程自带"通用参考组件"（device / network / storage / system / ...）+ 业务组件，通过显式注册决定启用哪些。

---

## 快速开始

### 1. H5 端（coconut.js）

```js
import { CoconutBridge } from './coconutWebBox/coconut.js';

const res = await CoconutBridge.call('device.getInfo', {});
console.log(res.result); // { manufacturer, model, ... }

// 环境检测
CoconutBridge.env.isIOS      // iOS WebView
CoconutBridge.env.isAndroid  // Android WebView
CoconutBridge.env.isHarmony  // Harmony WebView
CoconutBridge.env.isNative   // 任一原生环境
```

详细用法见 [`coconutWebBox/README.md`](./coconutWebBox/README.md)。

### 2. iOS（Xcode + SPM）

```bash
cd iOSWebBox
open iOSWebBox.xcodeproj
# Cmd+R 运行 iOSWebBox scheme 到 iPhone 模拟器
```

CoconutSDK 是内嵌的 SPM 包（`iOSWebBox/CoconutSDK/`），无需额外配置。组件在 `iOSWebBox/iOSWebBox/Components/` 下，注册在 `SceneDelegate.swift`。

离线包：`presentWebVC(with: "coconut://demo/index.html")` —— `CoconutSchemeHandler`（WKURLSchemeHandler）本地服务，无需网络。热更新：`CoconutUpdateManager.shared.checkUpdate/performUpdate/rollback`（demo 按钮入口，fixture 见 `scripts/serve-hot-update.sh`）。

### 3. Android（Android Studio + Gradle）

```bash
cd AndroidWebBox
./gradlew installDebug   # 装到连着的设备
```

模块依赖：`app` → `coconut-sdk` → `coconut-core` → `coconut-network`（HTTP 引擎，热更新经它下载），`app` → `coconut-network`（NetworkComponent 直用）。组件在 `app/src/main/java/com/sniper/androidwebbox/components/`，注册在 `WebBoxApplication.kt`。

集成到自己的 Android 项目见 [`AndroidWebBox/COCONUT_SDK_INTEGRATION.md`](./AndroidWebBox/COCONUT_SDK_INTEGRATION.md)。

离线包：`CoconutWebActivity.start(context, "coconut://demo/index.html")` —— 内置 assets + 沙箱覆盖本地服务，无需网络。热更新：`OfflineResourceManager.checkUpdate/performUpdate/rollback`（demo 按钮入口，fixture 见 `scripts/serve-hot-update.sh`；下载走 `coconut-network` 引擎，自动获得重试 / SSRF 守卫 / 统一超时）。Network：`NetworkComponent` 桥接独立 HTTP 引擎 `coconut-network` v1.1.0（纯 Kotlin JVM 库，**native-first**：一发式 API `client.get/post/put/delete` + bytes 模式，OkHttp 式分层 + 双 adapter HttpURLConnection/OkHttp + mock + SSRF 守卫，零 Android 依赖可单独复用），H5 `coconut.call('network', 'request'|'getNetworkType', …)`。

### 4. HarmonyOS NEXT（DevEco Studio）

需要 DevEco Studio + HarmonyOS 模拟器或真机。

```bash
cd HarmonyWebBox
hvigorw --mode module -p module=entry@default -p product=default assembleHap
```

或用 DevEco Studio 打开 `HarmonyWebBox/` 直接 Run。组件在 `entry/src/main/ets/components/`，注册在 `pages/Index.ets`。

离线包：`CoconutWebPage({ url: 'coconut://demo/index.html' })` —— rawfile + 沙箱覆盖本地服务，无需网络 / dev server。热更新：`CoconutUpdateManager.checkUpdate/performUpdate/rollback`（demo 按钮入口，manifest URL 用 Mac 局域网 IP，或 `hdc rport tcp:8000 tcp:8000` 后 127.0.0.1；下载走 `@coconut/network` 引擎，自动获得重试 / SSRF 守卫 / 统一超时）。Network：`NetworkComponent` 桥接独立 HTTP 引擎 `@coconut/network` v1.1.0（`CoconutNetwork/`，**native-first**：一发式 API + bytes 模式，OkHttp 式分层 + 可插拔 adapter + mock + SSRF 守卫，零依赖可单独给 native 项目用），H5 `coconut.call('network', 'request'|'getNetworkType', …)`。

---

## 测试

| 平台 | 框架 | 测试数 | 跑法 |
|------|------|--------|------|
| iOS | XCTest | 102 | `xcodebuild test -scheme CoconutSDK -destination 'id=<UDID>'` |
| Android | JUnit (JVM) | 191 | `./gradlew :coconut-core:testDebugUnitTest :coconut-network:test :app:testDebugUnitTest` |
| Harmony | Hypium (on-device) | 237 | `cd HarmonyWebBox && ./scripts/run-harmony-tests.sh` |

**Harmony 测试必须真机/模拟器跑**（crypto/UUID 需 HarmonyOS runtime）。一键脚本会自动 build + install + run + 写 markdown 报告到 `docs/`。

---

## 关键设计

- **三端对齐**：API 签名、错误码、安全机制三端必须一致（详见 [`API_CONTRACT.md`](./API_CONTRACT.md)）
- **SDK 纯净**：框架不含任何具体组件，组件由 App 装配
- **显式注册**：不扫描注解、不硬编码清单，App 决定启用哪些组件
- **安全分层**：BridgeToken / 域名白名单 / 限流，**三层均可独立开关**

每次 H5 → 原生的调用都经过这 3 层安全校验（详见 [`ARCHITECTURE.md`](./ARCHITECTURE.md#4-安全管线)）：

```
H5 call(component.method, params, bridgeToken)
   ↓
1. BridgeToken   UUID 会话令牌
2. 域名白名单    防恶意页面劫持
3. 限流         默认 100 次/分钟/method
   ↓
通过 → ComponentManager 路由到具体组件
失败 → 返回对应 ErrorCode
```

---

## 相关文档

**架构 / 契约**：
- [`ARCHITECTURE.md`](./ARCHITECTURE.md) — 三端模块结构、Bridge 通信、组件注册、安全管线对照
- [`API_CONTRACT.md`](./API_CONTRACT.md) — 组件方法签名、错误码命名空间、安全机制详细规范

**接入 / 用法**：
- [`coconutWebBox/README.md`](./coconutWebBox/README.md) — H5 端 JS Bridge 用法
- [`AndroidWebBox/COCONUT_SDK_INTEGRATION.md`](./AndroidWebBox/COCONUT_SDK_INTEGRATION.md) — Android 项目接入指南

**测试**：
- [`iOSWebBox/docs/EVENT_E2E_TEST.md`](./iOSWebBox/docs/EVENT_E2E_TEST.md) — iOS Event 订阅端到端测试（单元 + UI + Safari Inspector）
- [`AndroidWebBox/docs/EVENT_E2E_TEST.md`](./AndroidWebBox/docs/EVENT_E2E_TEST.md) — Android Event 订阅端到端测试（单元 + UI + CDP 自动化）
- [`HarmonyWebBox/docs/EVENT_E2E_TEST.md`](./HarmonyWebBox/docs/EVENT_E2E_TEST.md) — Harmony Event 订阅端到端测试（Hypium + UI + UiTest）
- [`HarmonyWebBox/scripts/run-harmony-tests.sh`](./HarmonyWebBox/scripts/run-harmony-tests.sh) — Harmony 测试一键脚本

---

## License

私有项目，未发布。
