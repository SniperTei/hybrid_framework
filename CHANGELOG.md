# Changelog

本文件记录 Coconut Hybrid Framework 的版本变更。格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

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
