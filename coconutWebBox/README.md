# 🥥 CoconutWebBox — Coconut SDK H5 测试项目

Coconut SDK 的 H5/Web 测试项目（Vue 3 + Vite），用于开发期联调 H5 ↔ 原生 Bridge。

> **当前协议版本：v3.5.1**（`component` + `function` 拆分、streaming、`__coconutConfig`、`coconut.dialog` / `coconut.navigator` 命名空间）。
> 详细 API 参考见仓库根 [`API_CONTRACT.md`](../API_CONTRACT.md)。

---

## 项目结构

```
coconutWebBox/
├── public/
│   └── coconut.js          # 📦 Coconut H5 SDK（源文件 / 分发用）
├── src/
│   ├── components/
│   │   └── Demo.vue        # 测试页面（device / storage / event / dialog / network / navigator 六组件 + env / lifecycle）
│   ├── App.vue             # 根组件
│   └── main.js             # 入口文件
├── index.html              # HTML 模板
├── vite.config.js          # Vite 配置
└── package.json
```

> 生产用的 `coconut_index.html`（三端字节级一致、device / storage / event / dialog / network / navigator 六组按钮）是**另一套独立前端**，与本 Vue 项目未打通。本项目的 `public/coconut.js` 才是分发用的 SDK 源文件，三端 copy 自此处。

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

   // 命名空间快捷方法（v3.3.0 dialog / v3.5.0 navigator）
   coconut.dialog.toast({ message: 'hi', duration: 2 });
   coconut.navigator.forward({ url: '/detail', params: { id: 1 } }, (err, data) => { /* ... */ });
   coconut.navigator.close({ result: { id: 1 } });

   // 事件订阅（native → H5 push）
   coconut.on('test.echo', (eventData) => { /* ... */ });
   coconut.off('test.echo');
   ```

### 版本要求

- coconut.js 当前版本 **3.5.1**（见文件头部 `@version` 注释）
- Bridge 协议主版本 = `coconut.env.hybridVersion` = `"3"`
- 协议要求：native 端 CoconutSDK **≥ 3.0.0**（三端任一）
- 不匹配的故障模式：H5 发 `component:function` 拆参数请求到旧 native（v2.x 仍读 `method` 字段）→ 返回 `code:'200001' UNKNOWN_COMPONENT`

### 更新方式

coconut.js 是单文件、零外部依赖。升级时：

1. 从本仓库 copy 最新版 coconut.js 覆盖你的 H5 项目
2. H5 重新 build / 部署
3. **不需要** native 端配合发版（只要协议没 breaking change）

### TypeScript 类型

`coconut.d.ts` 跟 `coconut.js` 同目录分发（三端 native 资源目录都带）。TypeScript 项目把 `.d.ts` 加进 `tsconfig.json` 的 `include` 或 `files` 即可获得类型提示：

```jsonc
// tsconfig.json
{
  "compilerOptions": { /* ... */ },
  "include": ["src", "vendor/coconut.d.ts"]
}
```

`.d.ts` 里 `declare global { const coconut: Coconut }` 自动给 `<script>` 加载的 `coconut` 全局变量配上类型，无需 `import`：

```ts
// 直接用，IDE 自动补全
const platform = coconut.env.platform;        // 'android' | 'ios' | 'harmony' | ...
const ok = coconut.supports('storage', 'setSize');  // boolean

coconut.call<{ value: string }>('storage', 'getItem', { key: 'k' }, (err, data) => {
  if (!err) console.log(data.value);          // string
});
```

显式标注类型时用 `import type`：

```ts
import type { Coconut, CoconutCallback, DeviceGetInfoResult } from './coconut.d';

const onInfo: CoconutCallback<DeviceGetInfoResult> = (err, data) => {
  if (!err) console.log(data.platform);
};
```

> 三端文件由 `scripts/sync-h5-assets.sh` 字节级同步；改了 `.d.ts` 后用脚本同步避免漏端。

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

`Demo.vue` 测试六个组件（与三端 `coconut_index.html` 对齐；未在某端注册的组件显示 skip，H5 侧先 `coconut.supports(component, fn)` 探测）：

> 另有 **`Settings.vue` 设置页**（真实业务试点，hash 路由 `#/settings`，三端 demo app 首页「设置页」按钮直达）：关于（env + device 信息）/ 检查更新（update 组件 check → dialog.confirm → apply → rollback）/ 存储管理 / 偏好开关（storage 持久化）/ 保存并关闭（navigator.close 回传 changed 列表）。

### device — 获取设备信息
- `coconut.device.getInfo(cb)` → `{manufacturer, brand, model, osName, osVersion, platform, screenWidth, screenHeight}`

### storage — 本地存储
- `coconut.storage.setItem(key, value, cb)` / `getItem(key, cb)` / `removeItem(key, cb)`
- `coconut.storage.clear(cb)` / `getAllKeys(cb)` / `getLength(cb)`

### event — native → H5 push
- `coconut.on(topic, cb)` —— 订阅事件，cb 收到的是 event.data
- `coconut.off(topic)` —— 取消订阅
- `coconut.call('event', 'echo', payload, cb)` —— 自验证：500ms 后 native 推送 `test.echo` 事件

### dialog — 原生弹窗（v3.3.0）
- `coconut.dialog.toast({ message, duration?, position? }, cb)` —— 非阻塞 toast（Run All 只测 toast；alert/confirm 需用户交互）

### network — 原生 HTTP 请求 + 网络状态（v3.4.0）
- `coconut.call('network', 'request', { url, method, body?, timeoutMs? }, cb)` —— 走 native HTTP 引擎（重试 / SSRF 守卫）
- `coconut.call('network', 'getNetworkType', {}, cb)` → `{ type: 'wifi'|'cellular'|..., online }`
- `coconut.on('network.change', cb)` —— 网络状态变化推送

### navigator — 容器导航（v3.5.0）
- `coconut.navigator.forward({ url, params?, header?, template? }, cb)` —— 开新容器（相对 URL 自动解析；header 覆盖导航栏配置）
- `coconut.navigator.back(cb)` —— 返回（WebView 历史，根页退化为关容器）
- `coconut.navigator.backToTop(cb)` —— 滚回顶部（native viewport scroll）
- `coconut.navigator.close({ result? }, cb)` —— 关当前容器；带 result 时前一容器收 `nav.result` 事件
- `coconut.on('nav.button', ({ side }) => ...)` —— 容器导航栏自定义按钮点击

### lifecycle — 内置事件（无需注册组件）
- `coconut.on('app.foreground', cb)` —— WebView 由隐藏转可见（app 切回前台）时触发
- `coconut.on('app.background', cb)` —— WebView 由可见转隐藏（app 切到后台）时触发
- cb 收到 `{ topic, timestamp }`
- 依赖 `document.visibilitychange`，三端 WebView 原生支持，无需 native 代码

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
