# 🥥 CoconutWebBox — Coconut SDK H5 测试项目

Coconut SDK 的 H5/Web 测试项目（Vue 3 + Vite），用于开发期联调 H5 ↔ 原生 Bridge。

> ⚠️ **状态腐化说明**
> 这个项目早期是为了测试完整的 14 个组件建的。2026-07-26 三端 trim 到只剩 device + storage（commit `3b3b6de` / `8a1437f` / `95b632a`）后，`Demo.vue` 还在调已删组件（network/system/security），**只有 device + storage 的测试还有效**。
> 等下次激活新组件时再回头修 `Demo.vue`。
>
> 另外：生产用的 `coconut_index.html`（三端字节级一致、只有 device + storage 两按钮）是**另一套独立前端**，和本 Vue 项目没打通。本项目的 `public/coconut.js` 才是分发用的 SDK 文件。

---

## 项目结构

```
coconutWebBox/
├── public/
│   └── coconut.js          # 📦 Coconut H5 SDK（分发文件，见下方"业务方集成"）
├── src/
│   ├── components/
│   │   └── Demo.vue        # ⚠️ 测试页面（部分组件已删，见状态说明）
│   ├── App.vue             # 根组件
│   └── main.js             # 入口文件
├── index.html              # HTML 模板
├── vite.config.js          # Vite 配置
└── package.json
```

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
   引入后会自动检测环境（android / ios / harmony / web）并初始化，全局挂载 `window.Coconut`。

3. **调用 API**

   ```js
   // Promise 方式（推荐）
   const resp = await Coconut.callAsync('device.getInfo', {});
   // resp.code === '000000' 表示成功，resp.result 是结果对象

   // 回调方式
   Coconut.call('storage.setItem', { key: 'foo', value: 'bar' }, (resp, isError) => {
     if (!isError) console.log('saved');
   });

   // 快捷方法（当前只暴露 device 和 storage 两组）
   Coconut.device.getInfo(cb);
   Coconut.storage.setItem(key, value, cb);
   Coconut.storage.getItem(key, cb);
   ```

### 版本要求

- coconut.js 当前版本 **2.2.0**（见文件头部 `@version` 注释）
- 协议要求：native 端 CoconutSDK **≥ 2.0.0**（三端任一）
- 不匹配的故障模式：H5 call 来 native 解析不了的 method → 返回 `code:'200001' UNKNOWN_COMPONENT` 或 `code:'200002' UNKNOWN_FUNCTION`

### 更新方式

coconut.js 是单文件、零外部依赖。升级时：

1. 从本仓库 copy 最新版 coconut.js 覆盖
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

- **Android**：`CoconutWebActivity.kt` 里 `webView.loadUrl(...)`
- **iOS**：`CoconutWebViewController(url: URL(string: "http://...")!)`
- **Harmony**：`CoconutWebPage({ url: 'http://...' })`

### 3. 生产部署（打包到 native assets）

```bash
npm run build
# 把 dist/ 内容拷贝到三端对应的资源目录：
cp -r dist/* AndroidWebBox/app/src/main/assets/coconut-web/
cp -r dist/* iOSWebBox/iOSWebBox/coconut-web/
cp -r dist/* HarmonyWebBox/entry/src/main/resources/rawfile/coconut-web/
```

---

## 当前可用组件测试

`Demo.vue` 里**只有这两个组件的测试还有效**（其他组件已从 main 删除）：

### device — 获取设备信息
- `device.getInfo` → `{manufacturer, brand, model, osName, osVersion, platform, screenWidth, screenHeight}`
- `device.getSystemInfo` / `device.getAppInfo` / `device.getAll`

### storage — 本地存储
- `storage.getItem(key)` / `storage.setItem(key, value)` / `storage.removeItem(key)`
- `storage.clear` / `storage.getAllKeys` / `storage.getLength`

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
- [`../API_CONTRACT.md`](../API_CONTRACT.md) — 三端 API 契约（组件方法签名、错误码）
- [`../AndroidWebBox/COCONUT_SDK_INTEGRATION.md`](../AndroidWebBox/COCONUT_SDK_INTEGRATION.md) — Android SDK 集成指南
- [`../iOSWebBox/CoconutSDK/README.md`](../iOSWebBox/CoconutSDK/README.md) — iOS SDK 集成
- [`../HarmonyWebBox/CoconutSDK/README.md`](../HarmonyWebBox/CoconutSDK/README.md) — Harmony SDK 集成

---

## 🎯 下一步（待办）

- [ ] `Demo.vue` 状态腐化修复：删除已删组件的测试代码（network/system/security/camera）
- [ ] 与生产用的 `coconut_index.html` 整合（一套前端 vs 两套）
- [ ] 等组件数量回升后，重新补 E2E 测试
