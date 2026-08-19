# Changelog

本文件记录 Coconut Hybrid Framework 的版本变更。格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

## [Unreleased]

热更新（离线包续集）：逐文件下载 + 版本比对 + 原子切换 + 回滚，三端对齐。`checkUpdate / performUpdate / rollback` 三 API，native demo 按钮触发，无 H5 bridge 组件、无进度回调。架构详见 `ARCHITECTURE.md` §7。

### Added

- **Android**（`a2a57af`/`8bcb417`）：`OfflineResourceManager` 新增更新 API + 22 个 JVM 测试（compareVersions / 路径守卫 / md5 向量 / staging swap / rollback 真值表）。
- **iOS**（`b1dbba5`/`82f75b1`）：`CoconutUpdateManager.swift`（CryptoKit MD5）+ 15 个 XCTest；HomeViewController 检查更新 / 回滚按钮。
- **Harmony**（`7d7152c`/`9d90203`）：`CoconutUpdateManager.ets` + 19 个 Hypium 测试；Index.ets 按钮 + manifest URL 输入框（须 Mac 局域网 IP）。
- **e2e fixture**：`scripts/serve-hot-update.sh`（bump 1.0.1 + 注 marker + 重算哈希；`--corrupt` 篡改哈希供失败路径）。
- 三端 demo 按钮入口（检查更新可用即自动下载应用 / 回滚到内置版本）。

### Changed

- 删除 Android 休眠的 zip 热更新路径（`dd30092`）—— 单一机制（逐文件），git 可找回。

### Fixed

- Harmony manifest 解析不容忍 pretty-print JSON（`"key": "value"` 带空格）→ 空白容忍正则 + 回归测试（e2e 抓到，单测漏网）。
- Harmony `fileIo.mkdirSync` 目标已存在时抛 "File exists"（recursive=true 也抛）→ 全部建目录走守卫 `ensureDir`，否则 performUpdate 首个根级文件即失败、version.json 永不落盘（e2e 抓到）。
- Harmony `cryptoFramework` MD5 在部分模拟器镜像 HUKS 层失败 → 纯 JS RFC 1321 实现（已知向量钉死）。

## [3.3.0] - 2026-08-18

离线包（方向 4a 最小版）：`coconut://` 统一 scheme，coconutWebBox vite 构建产物打包进 App 本地服务，三端沙箱覆盖层为热更新预留。**不含**动态更新（下载 / 版本比对 / 回滚）。架构详见 `ARCHITECTURE.md` §7。三端 e2e 全过：iOS Run All 全序列 + scheme handler stop() 路径；Harmony / Android 模拟器 Run All 16/16 + 沙箱覆盖证明（adb push / run-as overlay → 生效 → 回落内置包）。

### Added

- **Dialog 组件复活**（`cff5853`/`11d5ae3`/`f126161`，2026-08-15）：三端 `DialogComponent`（alert / confirm / toast / showLoading / hideLoading；prompt 不恢复——旧实现坏）。coconut.js v3.3.0 新增 `coconut.dialog` 命名空间；Run All 增至 16 项（+dialog.toast）。Android loading 弃 ProgressDialog 用 AlertDialog+ProgressBar；Harmony loading 真实现（openCustomDialog + ComponentContent）。契约移入 API_CONTRACT.md §4.4。
- **H5 构建管线**（`67a0149`）：vite 相对 base + 无 hash 文件名 + `scripts/build-offline-package.sh`（构建 + manifest 生成 + 三端全量分发，`--check` CI 校验）。
- **Android 离线包服务**（`9b7629a`）：`coconut://` 主帧翻译成 `file:///android_asset/coconut-web/…`，复用休眠的 `OfflineResourceManager` 拦截（沙箱 > assets）。
- **iOS `CoconutSchemeHandler`**（`c413cfb`）：`WKURLSchemeHandler` 注册 `coconut` scheme，沙箱 > bundle 查找，in-flight task 守卫 stop() 后回调 crash。
- **Harmony 离线包服务**（`5f419fd`）：主帧翻译成 `resource://rawfile/…` + `onInterceptRequest` 沙箱 > rawfile 服务（`CoconutOfflineResources`，13 个 Hypium 测试）。
- 三端 bridge 安全豁免非 http(s) scheme（`8fcabf6`）：`coconut://` / `file://` / `resource://` 页面不走域名白名单。

### Fixed

- **module script 在离线 scheme 下被 CORS 拦截**（`7fa83d9`）：ES module 规范上永远走 CORS 模式请求，`file://` / `resource://` 的 null origin 必被拒（Harmony 真机抓到）。构建管线改 rollup iife 输出 + 剥 `type="module"` / `crossorigin` 属性，一次修三端。
- **Android 沙箱覆盖层从未生效**：`coconut://` 曾翻译成 `file:///android_asset/…`，但 Chromium 对 `file:` scheme 不触发 `shouldInterceptRequest`，拦截路径（沙箱 > assets）整体静默旁路。改翻译成虚拟域 `https://coconut.local/coconut-web/…`，主帧 + 子资源可靠走拦截（模拟器 e2e：`adb push` 沙箱文件 → 红幅标记生效 → Run All 16/16 → 删除后回落 assets）。

## [3.2.0] - 2026-08-15

SDK 成熟度补齐轮：lifecycle hooks + 能力探测 + TypeScript 类型。三端（iOS / Android / HarmonyOS）实现并对齐，全部通过端到端验证（Run All 15/15 × 3 平台）。

### Added

- **Lifecycle 内置事件**（`2977ae7`）：coconut.js 监听 `document.visibilitychange`，派发 `app.foreground` / `app.background`，H5 用标准 `coconut.on()` 订阅。零 native 代码，三端 WebView 原生支持。限制：不覆盖 webview 销毁（无 `app.destroy`，文档已注明）。
- **能力探测 Capability Detection**（`1bc650b`）：
  - 三端组件基类新增 `methods: string[]`，每个组件显式声明 `handle()` 支持的方法
  - `ComponentManager.getCapabilities()` 聚合快照，随 `__coconutConfig` 注入 H5
  - coconut.js 新增 `coconut.env.capabilities`（lazy getter）+ `coconut.supports(component, fn)` 同步探测 helper
- **TypeScript 类型定义**（`705a171`）：`coconut.d.ts` 与 `coconut.js` 同步分发到三端，global `declare const coconut: Coconut` + named exports，`tsc --strict` 验证 0 错误。

### Changed

- 三端 native SDK 版本号从 2.0.0 对齐到 3.2.0（与 coconut.js / bridge 协议版本统一）。
- coconut.js `__coconutConfig` 注入契约新增 `capabilities` 字段（API_CONTRACT.md §0.1）。

### Fixed

- **Harmony bridge call 全挂 `300004 BRIDGE_TOKEN_INVALID`**（`42bdaf9`）：`CoconutSDK.configure()` 设了 `BridgeTokenManager.enabled = true` 但从不调 `generateToken()`，fail-closed 守卫拒掉所有请求。修复：configure 内条件调用 generateToken。
- **`storage.getLength` 不存在**（`5b89800`）：coconut.js 快捷方法名与 native 实现不一致，统一为 `getSize`。
- **Event 测试绕过 bridge**（`5b89800`）：测试代码直接操作 `coconut.handlers`，改为走 `coconut.on()` 完整 roundtrip。
- **Demo.vue capabilities panel 显示空**（`90bb708`）：Vue `computed()` 裸读 `window.__coconutConfig` 追踪不到 reactive deps。修复：coconut.js 注入完成后 dispatch `coconut:config-loaded` 事件 + Demo.vue 轮询兜底。
- **Demo.vue Run All 结果计数卡在 N-1/N**（`26c7e89`）：`startCheck()` 返回 raw object 而非 reactive proxy，`finishCheck()` 的状态更新绕过 Vue set trap。修复：从 reactive 数组取 proxy 返回。

### Security

- **BridgeTokenManager fail-open → fail-closed**（`dbb3fc6`）：token 为空时无条件放行改为拒绝，三端同步。
- **HMAC 签名机制整套移除**（`4ddbdc9`）：sharedSecret 经 `__coconutConfig` 注入 H5 后任何 JS 可读，属戏剧性安全。安全管线 5 层精简为 3 层（Token / 域名白名单 / 限流）。

## [3.1.0] - 2026-08-10

### Changed

- Wire 协议 `method` 字段拆分为顶级 `component` + `function`，三端同步。

## [3.0.0] - 2026-08-10

### Added

- coconut.js v3：lowercase `coconut` 唯一全局、error-first callback `cb(err, data)`、streaming 响应支持。

## [2.x] - 2026-07 ~ 2026-08

初始架构 + 13 组件实现后精简为 device / storage / event 三个核心组件。详见 git history。
