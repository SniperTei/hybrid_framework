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
| resource | ✅ | ✅ | ✅ | 三端必备 |
| router | ✅ | ✅ | ✅ | 三端必备 |
| performance | ✅ | ✅ | ✅ | 三端必备 |
| clipboard | ✅ | ✅ | ✅ | 三端必备 |
| stack | ✅ | ✅ | ✅ | 三端必备 |
| **camera** | ✅ | ❌ **缺** | ✅ | 三端必备（Android 待补） |
| **mytest** | ✅ | ❌ **缺** | ❌ **缺** | 可选（开发脚手架） |

---

## 2. ⚠️ 错误码命名空间（重大分歧）

三端错误码**两套命名空间**，互不兼容：

| 平台 | 参数校验 | 函数未实现 | 上下文不可用 | 组件未找到 |
|---|---|---|---|---|
| **iOS** | `200007` | `200002` | — | `200001` |
| **Android** | `900001` | `900002` | `900010` | `900001` |
| **Harmony** | `900001` | `900002` | `900010` | `900001` |

**标准决策**：统一采用 **Android/Harmony 的 9xxxxx 段**（已两端对齐，iOS 改造工作量小）。
具体规范见 ErrorCode 对照：

| 含义 | 标准码 |
|---|---|
| 参数校验失败 | `900001` |
| 函数/方法未实现 | `900002` |
| 上下文/Activity 不可用 | `900010` |
| 相机相关 | `900020`/`900030`/`900040` |
| 权限拒绝 | `200003`（保留业务语义码） |

> iOS 当前用的是 Bridge 层的 `ErrorCode.*`（200xxx/100xxx），需统一到 9xxxxx。

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

### 4.1 device

**标准签名**

| 方法 | params | returns |
|---|---|---|
| `getInfo` | — | `manufacturer, brand, model, deviceType, platform, screenWidth, screenHeight, screenScale` |
| `getSystemInfo` | — | `osName, osVersion, sdkVersion, model, localizedModel` |
| `getAppInfo` | — | `appName, packageName, version, buildNumber, debug` |
| `getAll` | — | `{ device, system, app }`（三个嵌套对象） |

**现状差异** 🔴 严重
- **getInfo 返回字段三端几乎全不同**：iOS 用 `device/product/platform`+屏幕尺寸；Android 用 `device/product/board/hardware/serial`；Harmony 用 `deviceType/marketName/productSeries`。
- **getAll 形状不一致**：iOS 是扁平结构 + 嵌套；Android/Harmony 是 `{device,system,app}` 三段。
- **getInfo 字段名**：iOS/Android `device` vs Harmony `deviceType`。

**对齐工作**：定义统一的 `device` 字段集合（建议：`manufacturer, brand, model, osName, osVersion, platform, screenWidth, screenHeight`），三端按可用性填充，缺则省略。

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
- Harmony **缺 `getSize`** 方法（iOS/Android 都有）。
- `value` 是否必填：iOS 默认""，Android 未标注，Harmony 必填 → 统一为「必填，空串报错」。

---

### 4.3 dialog 🔴 命名分歧严重

**标准签名**

| 方法 | params | returns |
|---|---|---|
| `alert` | `title, message, buttonText` | `confirmed` |
| `confirm` | `title, message, confirmText, cancelText` | `confirmed` |
| `toast` | `message*(string), duration(number,秒), position` | `success` |
| `showLoading` | `message` | `success` |
| `hideLoading` | — | `success` |
| `prompt` | `title, message, placeholder, confirmText, cancelText` | `confirmed, input` |

**现状差异** 🔴
- **confirm 按钮**：iOS 用 `confirmText`；Android/Harmony 用 `okText` → **标准用 `confirmText`**。
- **toast 方法名**：iOS/Android `toast`；Harmony `showToast` → **标准用 `toast`**。
- **toast duration 类型**：iOS 数字(秒)；Android/Harmony 字符串(`short`/`long`) → **标准用数字秒**（更通用）。
- **返回字段**：iOS 用 `shown`；Android/Harmony 用 `success` → **标准用 `success`**。
- **prompt**：只有 Harmony 实现 → 若保留则三端都加，否则从 Harmony 删除。

---

### 4.4 clipboard

**标准签名**

| 方法 | params | returns |
|---|---|---|
| `getText` | — | `text, hasText` |
| `setText` | `text*(string)` | `success` |
| `hasText` | — | `hasText` |
| `clear` | — | `success` |

**现状差异** 🟡
- iOS `getText` 多返回 `hasText`（保留为标准）；Android/Harmony 缺 → 补齐。
- `clear` 仅 Harmony 有 → 三端都加。

---

### 4.5 permission 🔴 返回值分歧

**标准签名**

| 方法 | params | returns |
|---|---|---|
| `check` | `permission*(string)` | `permission, status` |
| `request` | `permission*(string)` | `permission, status` |
| `openSettings` | — | `success` |

`status` 枚举：`authorized | denied | restricted | notDetermined | unsupported`

**现状差异** 🔴
- **返回字段**：iOS `{permission, status}`（字符串状态）；Android/Harmony `{permission, granted}`（布尔）。
- → **标准用 `status` 字符串**（信息更丰富，能区分 notDetermined/restricted）。Android/Harmony 需改造。
- 方法集：Harmony 多 `getAuthorized` → 三端都加或都不加。

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

### 4.8 stack 🔴 方法集几乎不同

**现状**（先列差异，标准需你拍板）

| 方法 | iOS | Android | Harmony |
|---|:---:|:---:|:---:|
| `push` | ✅ | ✅ | ✅ |
| `pop` | ✅ | ✅ | ✅ |
| `replace` | ✅ | ✅ | ✅ |
| `backTo` | ✅ | ✅ | ❌ |
| `getSize` | ✅ | ✅ | ❌ |
| `getStack` | ✅ | ✅ | ❌ |
| `canGoBack` | ✅ | ✅ | ❌ |
| `getCurrent` | ❌ | ❌ | ✅ |
| `getAll` | ❌ | ❌ | ✅ |
| `clear` | ❌ | ❌ | ✅ |

**标准决策建议**：以 iOS/Android 的方法集为准（`push/pop/replace/backTo/getSize/getStack/canGoBack`），Harmony 改造对齐。返回字段统一：`{success, action, stackSize}`。

---

### 4.9 resource 🔴 完全不同

**现状**：三端 API 几乎无交集。

| 平台 | 方法 | 关键参数 |
|---|---|---|
| iOS | `getVersion, getAllVersions, checkUpdate, applyUpdate` | `name, url, version` |
| Android | `getVersion, getAllVersions, checkUpdate, applyUpdate` | `moduleId, remoteVersion, downloadUrl, md5` |
| Harmony | `load, getResUrl, preload` | `name, names[]` |

**标准决策**：需你定方向——这个组件解决什么场景（热更新？本地资源访问？）再统一签名。建议参考 Android 的热更新能力（`checkUpdate/applyUpdate`）作为主路径，参数统一为 `moduleId, version, downloadUrl, md5`。

---

### 4.10 performance 🔴 Harmony 方法名完全不同

**标准签名**（以 iOS/Android 为准）

| 方法 | params | returns |
|---|---|---|
| `getMetrics` | — | `uptimeMs, totalCalls, totalSuccess, totalFail, successRate, methodCount` |
| `getMethodStats` | `method, all(boolean)` | `{方法级统计}` 或 `{methods[]}` |
| `getSlowCalls` | `threshold(number,ms)` | `{threshold, slowCallCount, slowCalls[]}` |
| `reset` | — | `success` |

**现状差异** 🔴 Harmony 用的是 `getStats / getHistory / resetStats`——**完全另一套命名**。需改造为 `getMetrics/getMethodStats/getSlowCalls/reset`。

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

### 4.13 camera（iOS + Harmony 已实现，Android 缺）

**标准签名**

| 方法 | params | returns |
|---|---|---|
| `takePhoto` | `frontCamera(boolean)` | `success, base64(data URL), message` |
| `scanQRCode` | `qrOnly(boolean), enableAlbum(boolean)` | `success, codeType, originalValue, message` |
| `isSupported` | — | `takePhoto, scanQRCode` |
| `showDialog` | `title, message, confirmText, cancelText` | `confirmed` |

**现状差异** 🟡
- `takePhoto` 返回：Harmony 多 `uri` 字段 → 保留为可选字段。
- `scanQRCode` 入参：Harmony 多 `enableAlbum/enableMultiMode` → 标准纳入 `enableAlbum`，`enableMultiMode` 可选。
- Harmony 有 `showCustomDialog`（第二个弹窗）→ iOS 待补或从 Harmony 删除。
- **Android 完全缺 camera 组件**，需新建。

---

### 4.14 mytest（可选脚手架）

**标准签名**

| 方法 | params | returns |
|---|---|---|
| `ping` | — | `pong, timestamp` |
| `echo` | `message*` | `message` |
| `add` | `a, b` | `sum` |

仅 iOS 实现。决策：要么三端都加（作为冒烟测试），要么从 iOS 删除。

---

## 5. 对齐工作清单（按优先级）

### P0 — 命名空间级分歧（影响所有调用）

1. **错误码统一到 9xxxxx 段**：iOS 改造 `ErrorCode.*` → 9xxxxx。
2. **dialog 三处命名统一**：`toast`(非 showToast) / `confirmText`(非 okText) / `duration` 数字秒 / 返回 `success`(非 shown)。
3. **performance 方法名统一**：Harmony `getStats/getHistory/resetStats` → `getMetrics/getMethodStats/getSlowCalls/reset`。

### P1 — 组件补齐

4. **Android 补 camera 组件**（参考 iOS/Harmony）。
5. **Harmony 补 storage.getSize**。
6. **Harmony stack 方法集对齐** iOS/Android（补 backTo/getSize/getStack/canGoBack）。

### P2 — 签名漂移

7. **permission 返回值**：Android/Harmony `granted(boolean)` → `status(string)`。
8. **device.getInfo 字段**：定义统一字段集，三端对齐。
9. **resource 组件**：定方向后三端重写对齐。
10. **clipboard.getText**：Android/Harmony 补 `hasText`；三端补 `clear`。

### P3 — 壳工程

11. **iOS demo 接入 WebView**（ViewController 目前为空），加载 coconut_index.html + 注入 bridgeToken。

---

## 6. 验收方式

每个 P0/P1 改完后，用三端共享的 `coconut_index.html` 点一遍按钮：
- 返回 `code:'000000'` 且 result 字段符合本契约 → 合规 ✅
- 字段缺失/命名不符 → 不合规 ❌

该 HTML 即 conformance test。
