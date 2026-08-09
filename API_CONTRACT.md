# Coconut 框架 API 契约

> **这份文档是三端（iOS / Android / Harmony）原生实现的权威契约。**
> H5 通过 `CoconutBridge.call('组件.方法', params)` 调用，每个组件方法的「标准签名」以本文档为准。
> 三端实现必须对齐到「标准签名」列；「现状差异」列记录当前漂移，用于追踪对齐进度。

---

## 0. 协议层（已对齐，三端一致）

| 项 | 规范 |
|---|---|
| 协议 | 类 JSON-RPC（无版本字段） |
| 请求 | `{ method:'组件.方法', params:{...}, id, bridgeToken }` |
| 响应 | `{ id, code:'000000', message, result:'<JSON字符串>' }` |
| 安全层 | bridgeToken + 域名白名单 + 限流 |
| 桥协议 | iOS=异步(postMessage) / Android=同步(JavascriptInterface) / Harmony=异步(javaScriptProxy) |

---

## 1. 组件可用性矩阵

> 当前活跃组件只有 2 个（commit `3b3b6de` / `8a1437f` / `95b632a`，2026-07-26 三端 trim）。
> 已删除的 12 个组件契约保留在文末「附录 A」供 git 历史参考。

| 组件 | iOS | Android | Harmony | 状态 |
|---|:---:|:---:|:---:|---|
| device | ✅ | ✅ | ✅ | 活跃 |
| storage | ✅ | ✅ | ✅ | 活跃 |

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

### 4.3 dialog（已删除）

> dialog 等 12 个组件已从 main 删除（commit `3b3b6de` / `8a1437f` / `95b632a`，2026-07-26）。
> 完整契约和实现要点移到**附录 A**，git 历史可找回完整源码。

---

## 5. 验收方式

用三端共享的 `coconut_index.html` 点一遍按钮（当前只有 device + storage 两组）：
- 返回 `code:'000000'` 且 result 字段符合本契约 → 合规 ✅
- 字段缺失/命名不符 → 不合规 ❌

该 HTML 即 conformance test。

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
6. 三端跑测试套件验证（iOS 64 / Android 61 / Harmony 112，目标数会回升）
