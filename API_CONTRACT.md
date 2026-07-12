# Coconut 框架 API 契约

> **这份文档是三端（iOS / Android / Harmony）原生实现的权威契约。**
> H5 通过 `CoconutBridge.call('组件.方法', params)` 调用，每个组件方法的「标准签名」以本文档为准。
> 三端实现必须对齐到「标准签名」列；「现状差异」列记录当前漂移，用于追踪对齐进度。

---

## 0. 协议层（已对齐，三端一致）

| 项 | 规范 |
|---|---|
| 协议 | JSON-RPC 2.0 |
| 请求 | `{ jsonrpc:'2.0', method:'组件.方法', params:{...}, id, bridgeToken }` |
| 响应 | `{ jsonrpc:'2.0', id, code:'000000', message, result:'<JSON字符串>' }` |
| 安全层 | bridgeToken + HMAC-SHA256 签名 + 域名白名单 + nonce 防重放 + 限流 |
| 桥协议 | iOS=异步(postMessage) / Android=同步(JavascriptInterface) / Harmony=异步(javaScriptProxy) |

---

## 1. 组件可用性矩阵

| 组件 | iOS | Android | Harmony | 标准化决策 |
|---|:---:|:---:|:---:|---|
| device | ✅ | ✅ | ✅ | 三端必备 |
| network | ✅ | ✅ | ✅ | 三端必备 |
| storage | ✅ | ✅ | ✅ | 三端必备 |
| system | ✅ | ✅ | ✅ | 三端必备 |
| security | ✅ | ✅ | ✅ | 三端必备 |
| dialog | ✅ | ✅ | ✅ | 三端必备 |
| permission | ✅ | ✅ | ✅ | 三端必备 |
| resource | ✅ | ✅ | ✅ | **可选 / 平台特定**（热更新 vs 本地资源加载语义不同，未标准化） |
| router | ✅ | ✅ | ✅ | 三端必备 |
| performance | ✅ | ✅ | ✅ | 三端必备 |
| clipboard | ✅ | ✅ | ✅ | 三端必备 |
| stack | ✅ | ✅ | ✅ | 三端必备 |
| **camera** | ✅ | ✅ | ✅ | 三端必备（Android 已补齐，scanQRCode 暂返回 not-supported） |
| **mytest** | ✅ | ✅ | ✅ | 三端必备（冒烟测试脚手架，已补齐 Android/Harmony） |

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

### 4.3 dialog ✅ 命名已对齐

**标准签名**

| 方法 | params | returns |
|---|---|---|
| `alert` | `title, message, buttonText` | `confirmed` |
| `confirm` | `title, message, confirmText, cancelText` | `confirmed` |
| `toast` | `message*(string), duration(number,秒), position` | `success` |
| `showLoading` | `message` | `success` |
| `hideLoading` | — | `success` |
| `prompt` | `title, message, placeholder, confirmText, cancelText` | `confirmed, input` |

**对齐结果** ✅ P0-2 已完成
- confirm 按钮参数：三端统一 `confirmText`（Android/Harmony 原 `okText` 已改名）。
- toast 方法名：三端统一 `toast`（Harmony 原 `showToast` 已改名）。
- toast duration 类型：三端统一数字秒（Android 按阈值映射 native SHORT/LONG；Harmony `秒*1000`）。
- 返回字段：三端统一 `success`（iOS 原 `shown`/`hidden` 已改名）。
- **遗留**：`prompt` 仅 Harmony 实现，待决策保留三端补齐或从 Harmony 删除。

---

### 4.4 clipboard

**标准签名**

| 方法 | params | returns |
|---|---|---|
| `getText` | — | `text, hasText` |
| `setText` | `text*(string)` | `success` |
| `hasText` | — | `hasText` |
| `clear` | — | `success` |

**对齐结果** ✅ P2-10 已完成
- iOS `getText` 已返回 `hasText`（原即如此）；Android/Harmony 已补齐。
- `clear` 三端都已实现（iOS/Android 新增，Harmony 原有）。

---

### 4.5 permission 🔴 返回值分歧

**标准签名**

| 方法 | params | returns |
|---|---|---|
| `check` | `permission*(string)` | `permission, status` |
| `request` | `permission*(string)` | `permission, status` |
| `openSettings` | — | `success` |

`status` 枚举：`authorized | denied | restricted | notDetermined | unsupported`

**对齐结果** ✅ P2-7 已完成
- 三端统一返回 `{permission, status}` 字符串字段。
- iOS 原即返回 `status`（信息最丰富：authorized/denied/restricted/notDetermined/limited/unsupported/authorizedWhenInUse）。
- Android/Harmony 已新增 `status` 字段（取值：authorized / denied / notDetermined），同时保留 `granted` 布尔字段以兼容现有 H5。
- 方法集差异：Harmony 保留额外 `getAuthorized`（非标准），三端标准方法集为 `check / request / openSettings`。

---

### 4.6 network ✅ 基本对齐

**标准签名**

| 方法 | params | returns |
|---|---|---|
| `getType` | — | `type` (`none/wifi/cellular/vpn/unknown`) |
| `getState` | — | `isConnected, type` |
| `isConnected` | — | `isConnected` |
| `request` | `url*(string), method, timeout, contentType, body, headers` | `statusCode, body, headers` |
| `get` | `url*, timeout, contentType, body, headers` | `statusCode, body, headers` |
| `post` | `url*, timeout, contentType, body, headers` | `statusCode, body, headers` |

**现状差异** 🟡
- `headers` 入参：iOS/Android 有；Harmony 未明确 → 补齐。
- Android 失败时返回 `{statusCode:-1, error}`（非标准）→ 统一走错误码而非负数 statusCode。

---

### 4.7 router ✅ 基本对齐

**标准签名**

| 方法 | params | returns |
|---|---|---|
| `open` | `url*(string), isNewWindow(boolean)` | `routed, type, page/path/url` |
| `back` | — | `success` |
| `getScheme` | — | `scheme, nativePrefix, h5Prefix` |

**现状差异** 🟡
- `isNewWindow` 类型：Android `boolean`；Harmony `string`('true'/'false') → **标准用 boolean**。
- iOS `open` 缺 `isNewWindow` 参数 → 补齐。

---

### 4.8 stack ✅ 方法集已对齐

**标准签名**（以 iOS/Android 为准）

| 方法 | params | returns |
|---|---|---|
| `push` | `url*(string)` | `success, action, stackSize` |
| `pop` | — | `success, action, stackSize` |
| `replace` | `url*(string)` | `success, action` |
| `backTo` | `index(number) \| url(string)` | `success, action, stackSize` |
| `getSize` | — | `size, currentIndex` |
| `getStack` | — | `currentIndex, totalSize, pages[]` |
| `canGoBack` | — | `canGoBack` |

**对齐结果** ✅ P1-6 已完成
- Harmony 已补齐 `backTo` / `getSize` / `getStack` / `canGoBack` 四个标准方法。
- `backTo` 支持 `index`（0-based）或 `url`（子串匹配）两种寻址。
- Harmony 保留原有 `getCurrent` / `getAll` / `clear` 作为附加能力（非标准、非契约）。

---

### 4.9 resource（暂未标准化，平台特定）

**现状**：三端实现解决不同问题，目前没有标准契约。

| 平台 | 方法 | 解决的场景 |
|---|---|---|
| iOS | `getVersion, getAllVersions, checkUpdate, applyUpdate` | 热更新（H5 资源包下载与版本管理） |
| Android | `getVersion, getAllVersions, checkUpdate, applyUpdate` | 热更新（同 iOS，参数命名略不同） |
| Harmony | `load, getResUrl, preload` | 本地 `$rawfile` 资源访问 |

**决策**：暂不统一。当前业务不接入热更新，三端实现各自保留但**不视为标准组件**——H5 调用方不应假设 `resource.*` 在三端行为一致。
- iOS/Android 的热更新骨架（`getVersion/checkUpdate/applyUpdate`）保留为「待激活」状态。
- Harmony 的本地资源加载保留为「平台扩展」。
- 等业务有明确方向（热更新或离线包统一管理），再回头定义标准签名并三端对齐。

---

### 4.10 performance ✅ 方法名已对齐

**标准签名**（以 iOS/Android 为准）

| 方法 | params | returns |
|---|---|---|
| `getMetrics` | — | `uptimeMs, totalCalls, totalSuccess, totalFail, successRate, methodCount` |
| `getMethodStats` | `method, all(boolean)` | `{方法级统计}` 或 `{methods[]}` |
| `getSlowCalls` | `threshold(number,ms)` | `{threshold, slowCallCount, slowCalls[]}` |
| `reset` | — | `success` |

**对齐结果** ✅ P0-3 已完成
- Harmony 原 `getStats/getHistory/resetStats` 已重命名为 `getMetrics/getMethodStats/getSlowCalls/reset`。
- Harmony `getHistory` 的「按 method 过滤历史」语义并入 `getMethodStats`（per-method stats），慢调语义由新 `getSlowCalls(threshold)` 承担（top 50、降序）。
- 返回字段对齐：`getMetrics` 扁平化（不再嵌套 methods 数组），`getSlowCalls` 用 `{threshold, slowCallCount, slowCalls[]}`。

---

### 4.11 security ✅ 对齐良好

**标准签名**

| 方法 | params | returns |
|---|---|---|
| `getAuditLog` | `type, limit(number)` | `count, entries[]` |
| `getAuditSummary` | — | `totalEvents, summary[]` |
| `getSecurityConfig` | — | `bridgeTokenEnabled, requestSigningEnabled, signingTimestampToleranceMs` |
| `clearAuditLog` | — | `success` |

三端基本一致，仅需统一返回字段名（Harmony `summary` 是 object，iOS/Android 是 array → 统一 array）。

---

### 4.12 system ✅ 基本对齐

**标准签名**

| 方法 | params | returns |
|---|---|---|
| `getVersion` | — | `sdkVersion, timestamp` |
| `getComponentVersion` | `name*` | `name, version, description, initialized` |
| `getAllComponents` | — | `count, components[]` |
| `checkCapability` | `method*` | `method, available, componentRegistered, componentInitialized` |

**现状差异** 🟡 Harmony `getComponentVersion` 返回 `{componentInfo:object}`（包了一层）→ 拍平为标准字段。

---

### 4.13 camera ✅ Android 已补齐（scanQRCode 占位）

**标准签名**

| 方法 | params | returns |
|---|---|---|
| `takePhoto` | `frontCamera(boolean)` | `success, base64(data URL), message` |
| `scanQRCode` | `qrOnly(boolean), enableAlbum(boolean)` | `success, codeType, originalValue, message` |
| `isSupported` | — | `takePhoto, scanQRCode` |
| `showDialog` | `title, message, confirmText, cancelText` | `confirmed` |

**对齐结果** ✅ P1-4 已完成
- Android CameraComponent 已新建并注册，方法集与 iOS/Harmony 对齐：`takePhoto` / `scanQRCode` / `isSupported` / `showDialog`。
- `takePhoto`：使用 `MediaStore.ACTION_IMAGE_CAPTURE` 走系统相机（无需新增第三方库），返回 JPEG data URL；通过新建的 `ActivityForResultDispatcher`（coconut-core）路由 `onActivityResult`。
- `showDialog`：复用 `AlertDialog`（与 DialogComponent.confirm 同款）。
- `scanQRCode`：Android 暂返回 `{success:false, message:'not yet supported'}`，等 QR 后端方案落地（决策见会话）。
- 仍需宿主 App 在 AndroidManifest 声明 `<uses-permission android:name="android.permission.CAMERA" />`（demo app 已加）。

---

### 4.14 mytest ✅ 已三端补齐

**标准签名**

| 方法 | params | returns |
|---|---|---|
| `ping` | — | `pong, timestamp` |
| `echo` | `message*` | `message` |
| `add` | `a, b` | `sum` |

三端均已实现，作为 Bridge 冒烟测试脚手架。

---

## 5. 对齐工作清单（按优先级）

### P0 — 命名空间级分歧（影响所有调用）

1. ✅ **错误码统一**（已完成）：Android/Harmony 组件层的 `9xxxxx` 全部替换为标准码（`200007` 参数校验 / `200001` 组件未找到 / `100005` 内部错误）。
2. ✅ **dialog 三处命名统一**（已完成）：`toast`(非 showToast) / `confirmText`(非 okText) / `duration` 数字秒 / 返回 `success`(非 shown)。
3. ✅ **performance 方法名统一**（已完成）：Harmony `getStats/getHistory/resetStats` → `getMetrics/getMethodStats/getSlowCalls/reset`，并拆分原 `getHistory` 的统计/慢调语义。

### P1 — 组件补齐 ✅ 全部完成

4. ✅ **Android 补 camera 组件**（已完成：takePhoto/showDialog/isSupported 已实现，scanQRCode 占位）。
5. ✅ **Harmony 补 storage.getSize**（已完成）。
6. ✅ **Harmony stack 方法集对齐** iOS/Android（已完成：补 backTo/getSize/getStack/canGoBack）。
7. ✅ **mytest 三端补齐**（已完成：Android + Harmony 新建，参考 iOS）。

### P2 — 签名漂移 ✅ 全部完成

7. ✅ **permission 返回值**（已完成）：Android/Harmony 新增 `status` 字符串字段（保留 `granted` 兼容）。
8. ✅ **device.getInfo 字段**（已完成）：三端统一返回 `manufacturer, brand, model, osName, osVersion, platform, screenWidth, screenHeight`；`getAll` 统一为 `{device, system, app}` 嵌套。
9. ✅ **resource 组件**（已决策）：暂不统一，标记为可选/平台特定（见 4.9）。
10. ✅ **clipboard.getText**（已完成）：Android/Harmony 补 `hasText`；三端补 `clear`。

### P3 — 壳工程

11. **iOS demo 接入 WebView**（ViewController 目前为空），加载 coconut_index.html + 注入 bridgeToken。

---

## 6. 验收方式

每个 P0/P1 改完后，用三端共享的 `coconut_index.html` 点一遍按钮：
- 返回 `code:'000000'` 且 result 字段符合本契约 → 合规 ✅
- 字段缺失/命名不符 → 不合规 ❌

该 HTML 即 conformance test。
