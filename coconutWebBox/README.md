# 🥥 CoconutWebBox — Coconut SDK H5 测试项目

Coconut SDK 的 H5/Web 测试项目（Vue 3 + Vite），用于开发期联调 H5 ↔ 原生 Bridge。

> **当前协议版本：v3.2.0**（`component` + `function` 拆分、streaming、`__coconutConfig`）。
> 详细 API 参考见仓库根 [`API_CONTRACT.md`](../API_CONTRACT.md)。

---

## 项目结构

```
coconutWebBox/
├── public/
│   └── coconut.js          # 📦 Coconut H5 SDK（源文件 / 分发用）
├── src/
│   ├── components/
│   │   └── Demo.vue        # 测试页面（device + storage + event）
│   ├── App.vue             # 根组件
│   └── main.js             # 入口文件
├── index.html              # HTML 模板
├── vite.config.js          # Vite 配置
└── package.json
```

> 生产用的 `coconut_index.html`（三端字节级一致、device + storage + event 三组按钮）是**另一套独立前端**，与本 Vue 项目未打通。本项目的 `public/coconut.js` 才是分发用的 SDK 源文件，三端 copy 自此处。

---

## 业务方如何集成 coconut.js

当前是**源码内嵌**模式（未来如果有 3+ 团队用，再升级到 npm 包）。

### 集成步骤

1. **复制 coconut.js 到你的 H5 项目**

   ```bash
   cp coconutWebBox/public/coconut.js <your-h5-project>/public/
   ```

2. **在 HTML 里 `<script>` 引入**

   ```html
   <script src="/coconut.js"></script>
   ```
   引入后自动检测环境（android / ios / harmony / web）并初始化，全局挂载小写 `window.coconut`。

3. **调用 API（error-first callback）**

   ```js
   // 通用 call（component + function 拆参数，v3.2.0 推荐）
   coconut.call('storage', 'setItem', { key: 'foo', value: 'bar' }, (err, data) => {
     if (err) {
       // err = { code: '200007', message: '...' }
     } else {
       // data = { key: 'foo', success: true }
     }
   });

   // Promise 版（一次性响应；不适用于流式响应）
   const data = await coconut.callAsync('device', 'getInfo', {});

   // 快捷方法
   coconut.device.getInfo((err, data) => { /* ... */ });
   coconut.storage.setItem(key, value, (err, data) => { /* ... */ });
   coconut.storage.getItem(key, (err, data) => { /* ... */ });

   // 事件订阅（native → H5 push）
   coconut.on('test.echo', (eventData) => { /* ... */ });
   coconut.off('test.echo');
   ```

### 版本要求

- coconut.js 当前版本 **3.2.0**（见文件头部 `@version` 注释）
- Bridge 协议主版本 = `coconut.env.hybridVersion` = `"3"`
- 协议要求：native 端 CoconutSDK **≥ 3.0.0**（三端任一）
- 不匹配的故障模式：H5 发 `component:function` 拆参数请求到旧 native（v2.x 仍读 `method` 字段）→ 返回 `code:'200001' UNKNOWN_COMPONENT`

### 更新方式

coconut.js 是单文件、零外部依赖。升级时：

1. 从本仓库 copy 最新版 coconut.js 覆盖你的 H5 项目
2. H5 重新 build / 部署
3. **不需要** native 端配合发版（只要协议没 breaking change）

---

## 🚀 快速开始（开发期联调）

### 1. 启动开发服务器

```bash
cd coconutWebBox
npm install
npm run dev
```

服务器会启动在 `http://localhost:5174`（Vite 已配 `host: '0.0.0.0'`，局域网可访问）。

### 2. 用 native demo 加载 dev server

把三端任一的 WebView URL 改成 `http://<你电脑的局域网 IP>:5174`：

| 平台 | 文件 | 加载方式 |
|---|---|---|
| Android | `CoconutWebActivity.kt` | `webView.loadUrl("http://...")` |
| iOS | `CoconutWebViewController.swift` | `WKWebView.load(URLRequest(url:))`，需 ATS 例外（见下） |
| Harmony | `CoconutWebPage.ets` | `Web({ src: 'http://...', controller })` |

### 3. 生产部署（打包到 native assets）

 coconut.js / coconut_index.html 三端路径：

| 平台 | coconut.js | coconut_index.html |
|---|---|---|
| Android | `AndroidWebBox/app/src/main/assets/` | 同左 |
| iOS | `iOSWebBox/iOSWebBox/`（bundle resource，`loadFileURL` 加载） | 同左 |
| Harmony | `HarmonyWebBox/entry/src/main/resources/rawfile/` | 同左 |

> 改完 `coconutWebBox/public/coconut.js` 后用 [`scripts/sync-h5-assets.sh`](../scripts/sync-h5-assets.sh) 同步到三端，避免手动 cp 漏端。

---

## 当前可用组件测试

`Demo.vue` 测试三个组件（与三端 `coconut_index.html` 对齐）：

### device — 获取设备信息
- `coconut.device.getInfo(cb)` → `{manufacturer, brand, model, osName, osVersion, platform, screenWidth, screenHeight}`

### storage — 本地存储
- `coconut.storage.setItem(key, value, cb)` / `getItem(key, cb)` / `removeItem(key, cb)`
- `coconut.storage.clear(cb)` / `getAllKeys(cb)` / `getLength(cb)`

### event — native → H5 push
- `coconut.on(topic, cb)` —— 订阅事件，cb 收到的是 event.data
- `coconut.off(topic)` —— 取消订阅
- `coconut.call('event', 'echo', payload, cb)` —— 自验证：500ms 后 native 推送 `test.echo` 事件

完整契约见仓库根 [`API_CONTRACT.md`](../API_CONTRACT.md)。

---

## 📱 多平台网络配置

### Android cleartext 配置（HTTP dev server）

`AndroidManifest.xml`：
```xml
<application android:usesCleartextTraffic="true" ...>
```

或用 `network_security_config.xml` 只放行 dev server IP。

### iOS ATS 例外（HTTP dev server）

`Info.plist`：
```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsLocalNetworking</key>
  <true/>
</dict>
```

### Harmony HTTP 权限

`module.json5` 加 `"ohos.permission.INTERNET"`；Web 组件默认支持 HTTP。

---

## 🐛 调试技巧

### Chrome DevTools 调 Android WebView

```kotlin
WebView.setWebContentsDebuggingEnabled(true)
```
然后 Chrome 访问 `chrome://inspect`。

### Safari 调 iOS WebView

Safari → 开发 → 模拟器/设备 → 选 WebView。

### Harmony DevTools

DevEco Studio → View → Tool Windows → Inspector/Web Inspector。

### 查看日志

```bash
# Android
adb logcat | grep Coconut

# iOS（模拟器）
xcrun simctl spawn booted log stream --predicate 'eventMessage CONTAINS "Coconut"'

# Harmony
hdc shell hilog | grep Coconut
```

---

## 📚 相关文档

- [`../README.md`](../README.md) — 仓库根 README（整体架构）
- [`../ARCHITECTURE.md`](../ARCHITECTURE.md) — 框架架构（Bridge / 安全管线 / 数据流）
- [`../API_CONTRACT.md`](../API_CONTRACT.md) — 三端 API 契约（权威，含 wire 协议、组件签名、错误码）
- [`../AndroidWebBox/COCONUT_SDK_INTEGRATION.md`](../AndroidWebBox/COCONUT_SDK_INTEGRATION.md) — Android SDK 集成指南
- [`../iOSWebBox/CoconutSDK/README.md`](../iOSWebBox/CoconutSDK/README.md) — iOS SDK 集成
- [`../HarmonyWebBox/CoconutSDK/README.md`](../HarmonyWebBox/CoconutSDK/README.md) — Harmony SDK 集成
