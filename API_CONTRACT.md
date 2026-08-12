# Coconut 框架 API 契约

> **这份文档是三端（iOS / Android / Harmony）原生实现的权威契约。**
> H5 通过 `coconut.call(component, functionName, params, callback)` 调用，每个组件方法的「标准签名」以本文档为准。
> 三端实现必须对齐到「标准签名」列；「现状差异」列记录当前漂移，用于追踪对齐进度。
>
> **当前协议版本：v3.2.0**（`component` + `function` 拆分、streaming 流式响应、`__coconutConfig` 注入）。

---

## 0. 协议层（v3.2.0，三端一致）

| 项 | 规范 |
|---|---|
| 协议 | 类 JSON-RPC（无版本字段，主版本号 = `coconut.env.hybridVersion` = `"3"`） |
| 请求 | `{ component:'storage', function:'setItem', params:{...}, id, bridgeToken }` |
| 响应（一次性） | `{ id, code:'000000', message, result:'<JSON字符串或对象>' }` |
| 响应（流式） | `{ id, code:'000000', message, result, streaming:true }` —— callback 不释放，等下一次同 `id` 响应；最终响应不带 `streaming` 字段时释放 |
| 安全层 | bridgeToken + 域名白名单 + 限流 |
| 桥协议 | iOS=异步(postMessage) / Android=同步(JavascriptInterface) / Harmony=异步(javaScriptProxy) |

**Wire 字段拆分历史**：
- v3.0.0（2026-08-10）：lowercase `coconut` 全局 + error-first callback `cb(err, data)`
- v3.1.0（2026-08-10）：wire `method:'组件.方法'` 拆成两个顶级字段 `component` + `function`，避免 H5 端字符串拼接 + native 端字符串切割的两次脆弱解析
- v3.2.0（2026-08-11）：`coconut.env` 加 `hybridVersion` / `appName` / `appVersion`（lazy getter 从 `window.__coconutConfig` 读）

### 0.1 H5 SDK 集成

**SDK 文件**：`coconut.js`（UMD 单例，全局挂载小写 `window.coconut`）。三端 native 已把 `coconut.js` + `coconut_index.html` 作为独立 bundle resource 打包：

| 平台 | 路径 |
|---|---|
| Android | `AndroidWebBox/app/src/main/assets/coconut.js` |
| iOS | `iOSWebBox/iOSWebBox/coconut.js`（bundle resource，`loadFileURL` 加载） |
| Harmony | `HarmonyWebBox/entry/src/main/resources/rawfile/coconut.js` |

> 三端文件字节级一致，源文件在仓库根 `coconutWebBox/public/coconut.js`。修改请用 `scripts/sync-h5-assets.sh` 同步。

**HTML 引入**：

```html
<script src="coconut.js"></script>
```

引入后自动检测环境（android / ios / harmony / web）并初始化，全局挂载 `window.coconut`（小写）。

**`window.__coconutConfig` 注入契约**（native 在 `onPageFinished` / `didFinishNavigation` / `onPageEnd` 注入）：

```js
window.__coconutConfig = {
  token: '<UUID bridgeToken>',       // 必填，由 native BridgeTokenManager.generateToken() 生成
  appName: '<原生应用名>',            // 可选，空串时 coconut.env.appName 返回 ''
  appVersion: '<原生应用版本>',        // 可选，空串时 coconut.env.appVersion 返回 ''
  capabilities: {                    // 必填（v3.2.0+），由 ComponentManager.getCapabilities() 生成
    device:  ['getInfo', 'getSystemInfo', 'getAppInfo', 'getAll'],
    storage: ['setItem', 'getItem', 'removeItem', 'clear', 'getAllKeys', 'getSize'],
    event:   ['on', 'off', 'echo']
  }
};
// hybridVersion 不是 config 字段，是 SDK 编译期常量（当前 "3")
```

**能力探测**：H5 通过 `coconut.supports(component, functionName)` 同步查表，不发 bridge call：

```js
if (coconut.supports('storage', 'getSize')) {
  coconut.storage.getSize(cb);
} else {
  // 老版本 native 不支持 getSize，走 fallback
}
```

**`coconut.env` 字段**：

| 字段 | 来源 | 示例 |
|---|---|---|
| `platform` | 运行时检测 | `'android'` / `'ios'` / `'harmony'` / `'web'` / `'node'` |
| `isAndroid` / `isiOS` / `isHarmony` / `isWeb` / `isNode` / `isNative` | 派生 bool | — |
| `version` / `sdkVersion` | coconut.js 文件版本 | `'3.2.0'` |
| `hybridVersion` | Bridge 协议主版本（编译期常量） | `'3'` |
| `appName` / `appVersion` | lazy getter，每次访问读 `window.__coconutConfig` | — |
| `capabilities` | lazy getter，读 `__coconutConfig.capabilities`，形如 `{componentName: [method names]}` | `{device:['getInfo','getSystemInfo','getAppInfo','getAll'], storage:[...6], event:['on','off','echo']}` |
| `userAgent` / `language` / `screen*` / `viewport*` / `isMobile` / `isTouchDevice` 等 | 浏览器侧信息 | — |

**Error-first callback**：

```js
coconut.call('storage', 'setItem', { key: 'foo', value: 'bar' }, (err, data) => {
  if (err) {
    // err = { code: '200007', message: '...' }
  } else {
    // data = result object
  }
});
```

- 成功：`err = null`，`data = result`
- 失败：`err = { code, message }`，`data = undefined`
- 流式响应：每次响应都触发 callback；`response.streaming === true` 时 timer 重置，callback 保留；最终响应（无 `streaming`）触发 callback 后释放

**Lifecycle events（内置事件，无需注册组件）**

coconut.js 在 `init()` 里监听 `document.visibilitychange`，自动派发到标准事件通道，H5 用 `coconut.on(topic, cb)` 即可订阅：

| topic | 触发时机 | callback 收到的 data |
|---|---|---|
| `app.foreground` | WebView 由隐藏转可见（app 切回前台） | `{ topic:'app.foreground', timestamp:<ms> }` |
| `app.background` | WebView 由可见转隐藏（app 切到后台） | `{ topic:'app.background', timestamp:<ms> }` |

依赖：现代 WebView（WKWebView iOS 9+ / Chromium Android / Harmony ArkWeb）原生支持 `visibilitychange`，三端无需额外 native 代码。

**限制**：visibilitychange 不覆盖 webview 销毁场景，不提供 `app.destroy`。如有"webview 即将销毁"的需求，需要走 native 钩子（pagehide / 能力级事件）单独补。

派发路径跟 native 推送的事件一致（走 `coconut.handlers[topic]`），所以订阅 / 取消订阅 API 与 4.3 event 组件统一（`coconut.on` / `coconut.off`）。

---

## 1. 组件可用性矩阵

> 当前活跃组件有 3 个。device + storage 来自 commit `3b3b6de` / `8a1437f` / `95b632a`（2026-07-26 三端 trim）；
> event 为 2026-08-09 新增（native → H5 push 能力）。
> 已删除的 12 个组件契约保留在文末「附录 A」供 git 历史参考。

| 组件 | iOS | Android | Harmony | 状态 |
|---|:---:|:---:|:---:|---|
| device | ✅ | ✅ | ✅ | 活跃 |
| storage | ✅ | ✅ | ✅ | 活跃 |
| event | ✅ | ✅ | ✅ | 活跃（v2.4.0 on/off/emit API） |

---

## 2. ✅ 错误码命名空间（已统一）

三端 `ErrorCode` 常量定义**本就一致**（100xxx 标准 / 200xxx 业务 / 300xxx 安全）。
分歧出在**组件实现层**：Android/Harmony 的组件曾硬编码 `9xxxxx` 魔法字符串绕过 ErrorCode 常量，iOS 则一直用规范的 `200xxx/100xxx`。

**已完成**：Android/Harmony 组件层的 `9xxxxx` 全部替换为标准码。

| 含义 | 标准码 | 三端现状 |
|---|---|---|
| 参数校验失败 | `200007` (PARAM_VALIDATION_FAILED) | ✅ 已统一 |
| 函数/方法未实现 | `200002` (UNKNOWN_FUNCTION) | ✅ 已统一 |
| 组件未找到 | `200001` (UNKNOWN_COMPONENT) | ✅ 已统一 |
| 上下文不可用 / 运行时失败 | `100005` (INTERNAL_ERROR) | ✅ 已统一（原 `900010`/`900020`/`900030`/`900040` 全折叠） |
| 权限拒绝 | `200003` | ✅ |

> 实现差异（非契约差异）：Android 组件调 `paramValidationError()`/`internalError()` 助手；Harmony 组件走 `this.error('200007', ...)` 码值替换（因 Harmony 的 `error()` 返回字符串而非 throw，不适合用 throwing 助手）。H5 侧看到的码值三端一致。

---

## 3. 跨组件约定

| 约定 | 规范 | 现状 |
|---|---|---|
| 成功标识 | 顶层 `code:'000000'`，**不要**在 result 里放 success 字段表示"调用本身成功" | ✅ |
| 业务布尔 | result 内 `success:true/false` 仅用于"操作是否生效"（如 setItem、takePhoto 取消） | iOS 倾向用 `shown`，需统一到 `success` |
| 取消语义 | 用户取消不算错误，`code:'000000'` + `success:false` + `message:'User cancelled'` | ✅ |
| 时间戳 | 毫秒数（`Number`） | ✅ |

---

## 4. 各组件契约

> 格式：每组件一张「标准签名」表 + 「现状差异」。

### 4.1 device ✅ getInfo/getAll 字段已对齐

**标准签名**

| 方法 | params | returns |
|---|---|---|
| `getInfo` | — | `manufacturer, brand, model, osName, osVersion, platform, screenWidth, screenHeight, screenScale?` |
| `getSystemInfo` | — | `osName, osVersion, sdkVersion, model, localizedModel` |
| `getAppInfo` | — | `appName, packageName, version, buildNumber, debug` |
| `getAll` | — | `{ device, system, app }`（三个嵌套对象，形状同上） |

**对齐结果** ✅ P2-8 已完成
- `getInfo` 三端统一返回 `manufacturer, brand, model, osName, osVersion, platform, screenWidth, screenHeight`（screenScale 可选）。
  - `osName`：iOS="iOS" / Android="Android" / Harmony="HarmonyOS"
  - `platform`：`ios` / `android` / `harmony`
  - `osVersion`：iOS=systemVersion / Android=RELEASE / Harmony=osFullName
- `getSystemInfo` 统一字段：`osName, osVersion, sdkVersion, model, localizedModel`。
- `getAll` 三端统一为 `{device, system, app}` 嵌套结构（iOS 原扁平 merge 形状已修）。
- Android 屏幕尺寸通过 `Resources.getSystem().displayMetrics` 获取；Harmony 通过 `display.getDefaultDisplaySync()`。
- iOS 旧字段 `device/product/iOSVersion/userInterfaceIdiom` 已废弃；Android 旧字段 `device/product/board/hardware/serial` 已废弃；Harmony 旧字段 `deviceType/marketName/productSeries/osFullName/securityPatchTag/abiList/serial` 已废弃（仅在 getAll 嵌套 system 中保留 osFullName 作为 osVersion）。

---

### 4.2 storage ✅ 基本对齐

**标准签名**

| 方法 | params | returns |
|---|---|---|
| `setItem` | `key*(string), value*(string)` | `success` |
| `getItem` | `key*(string)` | `value, exists` |
| `removeItem` | `key*(string)` | `success` |
| `clear` | — | `success` |
| `getAllKeys` | — | `keys[], count` |
| `getSize` | — | `count, size` |

**现状差异** 🟡 轻微
- Harmony `getSize` 已补齐（与 iOS/Android 一致：`{count, size}`，size 为近似字节数）。
- `value` 是否必填：iOS 默认""，Android 未标注，Harmony 必填 → 统一为「必填，空串报错」。

---

### 4.3 event ✅ native → H5 推送通道

**目标**：H5 可以订阅 native 端发生的事件（如网络切换、App 前后台切换、推送到达）。Native 检测到事件时通过 `window.__coconutEvent(json)` 主动推送。

**核心约定**
- 订阅走现有 `coconut.call('event', 'on', ...)`，复用 Bridge 安全管线（Token / 域名 / 限流）。
- **一个 topic 一个 callback**：`on` 同 topic 二次调用会覆盖前一次（并 console.warn），消除"多订阅者管理 id"的复杂度。
- coconut.js 同步登记本地 callback 后再异步发 `event.on` 请求，消除 iOS/Harmony 异步响应窗口的事件丢失竞态。
- 仅 native 可 emit；H5 不能 publish（避免循环 / 跨 H5 通信复杂度）。
- 不支持 topic 通配符，精确字符串匹配。
- 页面 reload / 导航时 native 端必须 `clearAll()`，否则 stale emit 会投递到新页面（Harmony 关键修复，三端统一在 `onPageStarted` / `didStartProvisionalNavigation` / `onPageBegin` 触发）。

**标准签名**

| 方法 | params | returns | 副作用 |
|---|---|---|---|
| `on` | `topic*(string)` | `{topic}` | native 端登记订阅（覆盖式） |
| `off` | `topic*(string)` | `{topic, success:true}` | native 端移除订阅；未订阅时 no-op |
| `echo` | `data:object`（透传） | `{scheduled:true, topic:'test.echo'}` | 500ms 后 emit `test.echo` 事件，payload 为入参 |

**事件推送通道（独立于 Bridge response）**

Native emit 通过：
```js
window.__coconutEvent('{"topic":"test.echo","data":{...}}')
```
- 单 JSON 字符串参数（与 `__coconutIOSCallback` / `__coconutHarmonyCallback` 一致）。
- 三端共用同名回调，由 `coconut.js` 持久注册（与 `__coconutIOSCallback` 同生命周期）。
- **不走 Bridge 安全管线**（native trusted source）。

**H5 API（coconut.js v3.2.0+，事件 API 自 v2.4.0 起稳定）**

```js
// 订阅 — 无返回值，事件到达时 callback 被调用
coconut.on('network.change', (event) => {
  console.log(event.topic, event.data);
});
// 取消订阅 — 未订阅的 topic 直接 off 也安全
coconut.off('network.change');
// 自验证：500ms 后触发 test.echo 事件（v3.1.0+ 拆参数调用）
coconut.call('event', 'echo', { hello: 'world' });
```

**事件 payload shape（投递到 callback）**

```json
{ "topic": "test.echo", "data": <any> }
```

**测试覆盖**：Android 10 / iOS 10 / Harmony 10 case（on+emit、off、同 topic 覆盖、topic 不匹配、echo round-trip、无 jsExecutor 静默、clearAll、空参数拒绝、off 未订阅 no-op、JS 转义）。

---

### 4.4 dialog（已删除）

> dialog 等 12 个组件已从 main 删除（commit `3b3b6de` / `8a1437f` / `95b632a`，2026-07-26）。
> 完整契约和实现要点移到**附录 A**，git 历史可找回完整源码。

---

## 5. 验收方式

用三端共享的 `coconut_index.html` 点一遍按钮（device + storage + event 三组）：
- 返回 `code:'000000'` 且 result 字段符合本契约 → 合规 ✅
- 字段缺失/命名不符 → 不合规 ❌

该 HTML 即 conformance test。

事件端到端验证流程：
1. 点「订阅 test.echo」→ 期望 eventView 显示 `on ack`
2. 点「Echo」→ 500ms 后 eventView 显示 `event received`，payload 含 `{hello:'world'}`
3. 点「取消订阅」→ eventView 显示 `off ack`，再点 Echo 应**无**事件投递
4. Reload WebView → 再次 On → native 端 registry 已清空（无 stale 投递）

---

## 附录 A：已删除组件契约（历史参考）

> 以下 12 个组件在 2026-07-26 的三端 trim（commit `3b3b6de` / `8a1437f` / `95b632a`）中从 main 删除。
> 当前业务只用到 device + storage。下述契约保留供未来重新激活组件时直接复用，无需重新设计。
> 完整源码与配套基础设施（FileProvider / PermissionResultDispatcher / QrScannerActivity / file_paths.xml / Info.plist 权限声明 等）都在 git 历史里，`git log --grep=<组件名>` 可定位。

### A.1 简表

| 组件 | 主要方法 | 删除时的关键约定 |
|---|---|---|
| dialog | `alert / confirm / toast / showLoading / hideLoading / prompt` | 三端命名已对齐（`toast` 非 `showToast`，`confirmText` 非 `okText`，`duration` 数字秒，返回 `success`） |
| clipboard | `getText / setText / hasText / clear` | `getText` 返回 `{text, hasText}`，三端都有 `clear` |
| permission | `check / request / openSettings` | 统一返回 `{permission, status}`，`status` 枚举：`authorized / denied / restricted / notDetermined / unsupported` |
| network | `getType / getState / isConnected / request / get / post` | iOS/Android 有 `headers` 入参；Android 失败时应走错误码而非 `statusCode:-1` |
| router | `open / back / getScheme` | `isNewWindow` 标准用 `boolean`（Harmony 原 string 已对齐） |
| stack | `push / pop / replace / backTo / getSize / getStack / canGoBack` | `backTo` 支持 `index` 或 `url` 两种寻址 |
| resource | iOS/Android: `getVersion / checkUpdate / applyUpdate`；Harmony: `load / getResUrl / preload` | **未标准化**：iOS/Android 解决热更新，Harmony 解决本地资源访问，语义不同 |
| performance | `getMetrics / getMethodStats / getSlowCalls / reset` | Harmony 原 `getStats/getHistory/resetStats` 已对齐到标准名 |
| security | `getAuditLog / getAuditSummary / getSecurityConfig / clearAuditLog` | `getSecurityConfig` 现在只返回 `bridgeTokenEnabled`（HMAC 已删） |
| system | `getVersion / getComponentVersion / getAllComponents / checkCapability` | Harmony `getComponentVersion` 应拍平 `{componentInfo:object}` 到标准字段 |
| camera | `takePhoto / scanQRCode / isSupported / showDialog` | 见下方 A.2 详细合约 |
| mytest | `ping / echo / add` | Bridge 冒烟测试脚手架 |

### A.2 camera 详细合约（最复杂，单列）

**返回 shape 约定（三端必须一致）**

`takePhoto` 成功：
```json
{ "success": true,
  "uri":     "<平台特定>",   // iOS: file:///...    Android: content://...    Harmony: sandbox URI
  "base64":  "data:image/jpeg;base64,..." }
```
- 成功时 `uri` 与 `base64` **必须同时存在**。
- `uri` 仅保证在当前 WebView session 内有效（iOS=NSTemporaryDirectory，Android=cacheDir，均可能被系统回收）；H5 需要持久化请上传 `base64`。

`takePhoto` 失败/取消：
```json
{ "success": false, "message": "User cancelled" | "Camera permission denied" | ... }
```

`scanQRCode` 成功：
```json
{ "success": true, "codeType": "QR_CODE" | "EAN_13" | ..., "originalValue": "<解码字符串>" }
```
`scanQRCode` 失败/取消：`{ "success": false, "message": "..." }`（同 takePhoto）。

**权限拒绝走业务层**（不走 Bridge error code）：
- 三端在 takePhoto / scanQRCode 入口都做相机权限预检。
- 拒绝时返回 `code:"000000"` + `result.success:false` + `result.message:"Camera permission denied"`。
- 理由：`code:"200003"` 是 Bridge 安全层（Token / 域名）专用；权限提示是业务结果。混在一起 H5 错误处理会乱。这是组件层的通用模式。

**实现要点**（重新激活时直接用）
- iOS：`AVCaptureDevice.authorizationStatus(for: .video)` 预检；JPEG 写 `NSTemporaryDirectory()` 返回 `file://` uri。`Info.plist` 必须声明 `NSCameraUsageDescription`。
- Android：`ContextCompat.checkSelfPermission` + `PermissionResultDispatcher`（coconut-core）路由 `onRequestPermissionsResult`；JPEG 写 `cacheDir/coconut_photos/`，通过 `FileProvider`（authority `${applicationId}.fileprovider`）返回 `content://` uri。manifest 需声明 `<uses-permission android:name="android.permission.CAMERA" />` + FileProvider + `<cache-path>`。
- Android `scanQRCode`：用 **ML Kit barcode-scanning (bundled)**（无 GMS 依赖，HMS-only 设备能跑）+ **CameraX**。自定义 `QrScannerActivity` 持有相机预览 + 调 ML Kit 解码。ML Kit 的 int 格式常量映射成跨平台字符串名（`FORMAT_QR_CODE` → `"QR_CODE"`）以保持 shape 稳定。
  - 体积增量 ~5MB（ML Kit 模型 ~2.5MB + CameraX ~1.5MB + 预览 UI）。
  - 不用 ZXing 是因为想尽量用官方库；不用 ML Kit thin 变体（`play-services-mlkit-barcode-scanning`）是因为那个变体才真依赖 GMS。bundled 版本是纯 on-device。
- Harmony：`cameraPicker` 走系统 UI，已满足合约。`isSupported()` 曾硬编码 `true`，重新激活时建议用 `cameraPicker.isPickerSupported(mediaTypes)` 精确化。

### A.3 git 历史定位

```bash
# 找组件源码
git log --oneline --grep='camera'
git log --oneline --grep='permission'
git log --oneline --grep='dialog'

# 找回单文件
git log --all --full-history -- '**/CameraComponent.swift'
git show <commit>:<path>

# camera 全套 commits（7 个）
git log --oneline f90070e..1547473
```

### A.4 重新激活检查清单

重新引入某组件时：
1. 从 git 找回源码（按 A.3）
2. 三端同步加回（不要只加一端）
3. 恢复配套基础设施（FileProvider / 权限调度 / Info.plist 等）
4. 把本附录的对应行移回第 4 节
5. 在 `coconut_index.html`（三端字节级同步）加回测试按钮
6. 三端跑测试套件验证（当前基线：iOS 73 / Android 70 / Harmony 121，目标数会随组件恢复回升）
