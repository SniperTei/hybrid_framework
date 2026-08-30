# Changelog

本文件记录 Coconut Hybrid Framework 的版本变更。格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

## [Unreleased]

### Fixed（2026-08-30，Harmony RealApp e2e 抓出）

- **`coconut.js` v3.5.1 — Harmony 配置注入竞态自愈**：ArkWeb 的 `__coconutConfig`（含 bridge token）在 `onPageEnd` 注入，晚于 H5 首渲染与 mount 时的 bridge 调用 → 首轮调用全部 `300004`，且 `coconut:config-loaded` 只在下一次调用时经 `_applySecurity` 补发，页面卡在降级态直到用户手动触发。修法：`init()` 时配置未到位则 250ms 轮询（~10s 上限），到位后 `_loadSecurityConfig()` 补发 `config-loaded`。Android（同步注入）/ iOS（加载前注入）首轮命中零开销；纯浏览器 10s 放弃。配套 h5app：`HomeTab` 监听 configTick 重试 mount 调用（refreshNetwork / loadDeviceInfo），`lib/events.js` 新增 `resubscribeNative()`（`c.on` 300004 后 config 到位重订，重复注册覆盖语义无害）。

容器导航（v3.5.0，**三端齐活**）：H5 开新容器 / 返回 / 带结果关闭 + 导航栏配置 + 白屏错误弹窗。`coconut.js` v3.5.0 `coconut.navigator` 命名空间（三端同步下发，未落地平台 `supports('navigator')` gating）。契约详见 `API_CONTRACT.md` §4.6。

### Added（iOS 落地，2026-08-28）

- **NavConfig 三级合并链**（SPM CoconutSDK）：`CoconutConfig.nav ← defaultNavConfig（模板子类 open 钩子）← navOverride（forward header / native caller）`，逐字段 nil=继承；`visible / title(auto|fixed) / closePolicy(auto|always) / leftButtonText / rightButtonText` + `shouldShowClose(canGoBack:)`。单测真值表。
- **CoconutNavBarView 自绘导航栏**（不绑 UINavigationController——容器是 fullScreen modal 链）：返回 chevron/左文本 · AUTO（KVO `webView.title` + didCommit 补读）/FIXED 标题 · ×/右文本互斥；`nav.left`/`nav.right` accessibilityIdentifier。统一返回路径 `handleBack()` = `onBack()` 拦截 → `canGoBack ? goBack : dismiss`。
- **白屏错误弹窗**：`didFail`/`didFailProvisionalNavigation`（**过滤 NSURLErrorCancelled**——程序化导航伴随错误码）→ UIAlertController「重试」(reload)/「退出」(dismiss)；同次加载不叠弹；HTTP 4xx/5xx 不算（WKWebView 不报为失败）。`enableErrorDialog` 全局 + per-instance 开关；内联错误覆盖层删除。
- **NavigatorComponent**（第 6 个组件，app 层）：`forward / back / backToTop / close`。forward 缺 url/守卫拦截 → `200007`，`coconut://` 直通，栈深上限 10（静态活容器计数）→ 业务失败；backToTop = native `scrollView.setContentOffset`；close result → `NavResultBus` 单槽 → 前容器 `viewWillAppear` drain → `emitBypassingSubscription('nav.result')`。测试缝（stackDepth/launcher/templateResolver 可注入）。
- **多容器 resume-claim**：claim 挪到 `viewWillAppear`（setHost + generateToken + jsExecutor + pageLoaded 时重注入 config——吸收 Android `__coconutInitialized` 坑）；`deinit` 身份守卫（`host === self` 才清）+ `didCountContainer` 计数守卫。对象 result drain 时 `JSONSerialization` 解析回真 JSON（Harmony rawValue 同型问题结构性免疫，e2e ⑨ 钉死）。
- **模板容器（真继承）**：`CoconutWebViewController` 声明 `open`，模板 = 宿主子类（`defaultNavConfig` + `onBack/onLoadFail/onTitleChange` delegate 覆写）；`TemplateRegistry`（`NSClassFromString("Module.Class")` 强制模块前缀 + `isKind(of:)` 校验 + 重复名拒收 + eager 校验）+ `coconut_templates.json` + `DemoTemplateViewController` 示范（底部 native banner + FIXED 标题）。
- **nav.button 事件**：自定义按钮 tap → 有订阅 emit `{side}`；无订阅左键兜底返回、右键 no-op + Logger.w（与两端同语义）。
- **e2e：XCUITest 11 场景全过**（`ContainerNavE2ETests` 9 test：死链弹窗重试/退出、HTTP 500 不弹、A→B→C nav.result 逐级回传、根页 back 退化 dismiss、backToTop ack、11 层栈限、自定义按钮订阅语义、模板命中 + onBack 拦截、Run All 22/22 回归）。Autorun 结果写 `document.title`（iOS AUTO 导航栏原生镜像——backToTop 滚走结果面板后 WKWebView AX 树查不到面板文本的解法）。

### Fixed（iOS e2e 抓出，三端同型隐患）

- **Demo.vue Run All template 未注册检查错测**：检查发 `url: window.location.pathname`（=`/`）——UrlGuard 拦 scheme-less 相对路径（200007）在 template 查询之前，本想测「template 未注册 → success:false」实际测成守卫拦截（iOS 首跑 21/22 根因；Android/Harmony 同型隐患，只是尚未从根路径跑过 Run All）。修法：url 用绝对地址（`origin + pathname`）。

### Added（Harmony 落地，2026-08-26）

- **NavConfig + CoconutWebDelegate**（CoconutSDK HAR）：`NavConfig.ets`（三级合并链 `CoconutConfig.nav ← per-open header`，逐字段 null=继承，对齐 Android 语义）；`CoconutWebDelegate` 可继承钩子（onBack 拦截 / onLoadFail / onTitleChange）；`NavResultBus` 单槽。14 个真值表 Hypium 测试。
- **WebContainer 标准容器路由页**（@Entry）：`router.pushUrl({url, params:{url, header, errorDialog}})` 打开；自绘导航栏（左文本/返回 chevron · AUTO|FIXED 标题 · ×/右文本，不依赖 NavTitleBar）；统一返回路径 `handleBack()` = delegate 拦截 → WebView 历史 → 退化 `router.back()`；AUTO 标题 `onTitleReceive` 同步；白屏错误弹窗 `promptAction.showDialog`（重试=refresh / 退出=router.back，主帧判定 request url == 当前 url 启发式，`enableErrorDialog` 全局 + per-open 开关）。
- **NavigatorComponent**（第 6 个组件，app 层）：`forward / back / backToTop / close`，forward 过 UrlGuard + `coconut://` 直通 + 栈深上限 10（`router.getLength()`）；backToTop 用 `runJavaScript('window.scrollTo(0,0)')` fallback（webviewController 无 scrollTo）；close result → NavResultBus → 前容器 `onPageShow` drain → `emitBypassingSubscription('nav.result')`。测试缝五件套（stackDepth/launcher/templateResolver/hostWebController/backer 可注入 lambda）。
- **多容器 claim/release**：`onPageShow` 认领 jsExecutor（身份追踪）+ config 重注入（token 恒定，幂等）；`aboutToDisappear` 身份守卫释放。CoconutWebPage 内联错误覆盖层删除（职责由弹窗接管）。
- **模板容器**：`TemplateRegistry`（浅校验：JSON 解析 + 名称非空 + 重复名拒收；ArkTS 无反射，页面注册 main_pages 是文档化宿主契约）+ `coconut_templates.json` + `DemoTemplatePage` 示范（宿主原生底部 banner + FIXED 标题，注册名 "demo"）+ Index 启动期 eager 校验。
- **nav.button 事件**：自定义按钮 tap → 有订阅 emit `{side}`；无订阅左键兜底返回、右键 no-op + console.warn（与 Android 同语义）。

### Fixed（Harmony e2e 抓出）

- **close({result}) 对象 result 丢失**：`NavigatorComponent.rawValue` 的原始类型正则匹配不到对象值 → NavResultBus 拿不到 payload → 前容器永远收不到 `nav.result`。修法：深度感知扫描器（字符串/转义/嵌套大括号状态机）+ `backer` 测试缝 + 3 个回归测试。e2e 场景 ⑨ 抓出。

### Added（Android 先行，2026-08-25）

- **NavConfig 三级合并链**（coconut-core）：`CoconutConfig.nav ← defaultNavConfig（模板子类钩子）← per-open header`，逐字段 null=继承；`visible / title(auto|fixed) / closePolicy(auto|always) / leftButtonText / rightButtonText`。14 个真值表 JVM 测试。
- **导航栏 + 返回语义**：扩展现有 Toolbar——左键文本按钮（有则替换返回 icon）、右键自定义 action（有则替换 × 键）、× 显隐随 `doUpdateVisitedHistory` 重算；返回统一 `onNavBack()` = `canGoBack ? goBack : finish`（物理返回 / 导航栏 / navigator.back 同一条路）；`onReceivedTitle` → AUTO 模式标题同步。
- **错误弹窗（白屏救援）**：`onReceivedError`（仅 main frame）→ AlertDialog「重试」/「退出」，`onPageStarted` dismiss 防叠弹；`CoconutConfig.enableErrorDialog` 全局开关 + `EXTRA_ENABLE_ERROR_DIALOG` per-open。**`onReceivedHttpError` 整块移除**（HTTP 4xx/5xx 渲染 server body，不算白屏）。
- **NavigatorComponent**（第 6 个组件，app 层）：`forward / back / backToTop / close`。forward：url 必填（缺/守卫拦截 → `200007`）、`coconut://` scheme 直通、相对 URL js 侧解析、params 扁平 kv → query、header → NavConfig per-open；栈深上限 10（`success:false` 业务失败）；close 的 result → `NavResultBus` 单槽 → 前一容器 resume 时 emit `nav.result`。测试缝：stackDepth 供应商 / activity starter / 模板解析器可注入 lambda。14 个 JVM 测试。
- **模板容器**：`TemplateRegistry`（coconut-core，kotlinx.serialization 解析 `assets/coconut_templates.json` + `Class.forName` 反射 + `isAssignableFrom` 校验）；`DemoTemplateActivity` 示范（FIXED 标题 + 自定义右键，注册名 "demo"）；`consumer-rules.pro` R8 keep。8 个 JVM 测试。
- **多容器 resume-claim 模型**（重构）：host 认领 + token 生成 + jsExecutor 接线从 onCreate 挪到 onResume；onDestroy 身份守卫（`host === this` 才清 host/reset token）；resume 时 config 重注入刷新页内 token。修复两个多容器隐性 bug（见 Fixed）。
- **coconut.js v3.5.0**：`coconut.navigator` 命名空间（forward 相对 URL 解析 / back / backToTop / close(result|cb)）+ `coconut.d.ts` Navigator 类型；Demo.vue Navigator 区（8 按钮）+ Run All 增至 22 项（守卫 200007 / 未注册模板 / backToTop ack）；coconut_index.html 三端同步第六组按钮。
- **nav.button 事件**：自定义按钮 tap → 有订阅 emit `{side}`；无订阅左键兜底返回、右键 no-op + Logger.w。

### Fixed

- **forward 假成功（静默丢 intent）**：`FLAG_ACTIVITY_NEW_TASK` + 同类 Activity 已在栈顶 → 系统 dedupe 到既有实例且不触发 onNewIntent，forward 返回 success 但无新容器。修法：Activity context 启动不带 NEW_TASK（plain `startActivity` LIFO 压栈；非 Activity context 保留 NEW_TASK）。e2e 场景 A→B→C 抓出。
- **容器恢复后 300004（旧 token）**：注入脚本 `__coconutInitialized` 早退守卫挡掉 resume 时 config 重注入 → 页面持有旧 bridge token，恢复后所有调用失败。修法：`__coconutConfig` 赋值 + `_loadSecurityConfig()` 每次注入必跑，init 标志只 gate 日志。e2e 场景 B 恢复后 back 抓出。

### Removed

- **ErrorPageHelper 整套删除**（用户拍板；git history 可找回）：showErrorPage / hideErrorPage / errorPageView，职责由错误弹窗接管。

### Android e2e（11 场景全过，emulator-5556）

dead URL 弹窗重试/退出、HTTP 500 不弹、A→B→C 多级返回链、根页 back 退化关闭、backToTop、守卫拦截 200007、11 层超限、自定义按钮有/无订阅两分支、close({result}) → nav.result 回传、模板命中/未注册、Run All 22/22 回归。

### Harmony e2e（11 场景全过，模拟器 127.0.0.1:5555，2026-08-26）

同 11 场景清单全过（fixed overlay 断言通道 + `?op=` query driver 页 + hdc rport 反向转发打 vite dev server）。设备测试 280/280（237 → +43：NavConfig 真值表 14 / NavigatorComponent 15+3 / TemplateRegistry 8 / CoconutWebPage delegate 3 等）。

## [3.4.0] - 2026-08-23

Network 组件（三端齐活）：H5 请求走 native HTTP 栈 + 网络状态。引擎为独立库且 **native-first**（主要消费者是热更新等 native 代码）——Harmony HAR `@coconut/network` v1.1.0 / Android 纯 Kotlin JVM `coconut-network` v1.1.0 / iOS Swift Package `CoconutNetwork` v1.1.0（均零依赖，可单独用于纯 native 项目；三平台 API 已对齐：一发式 `client.get/post/put/delete` + bytes 模式），`NetworkComponent` 桥接到 H5 bridge。契约详见 `API_CONTRACT.md` §4.5。

热更新（离线包续集）：逐文件下载 + 版本比对 + 原子切换 + 回滚，三端对齐。`checkUpdate / performUpdate / rollback` 三 API，native demo 按钮触发，无 H5 bridge 组件、无进度回调。架构详见 `ARCHITECTURE.md` §7。

### Added

- **CoconutNetwork 独立 HAR**（`781ef8e`）：OkHttp 式分层（HttpClient / Call / HttpRequest / HttpResponse / interceptors），adapter 可插拔传输（默认 HarmonyHttpAdapter，测试 FakeAdapter，第三方栈可实现 IHttpAdapter 接入），MockInterceptor 规则命中即短路，引擎级 SSRF UrlGuard（scheme 白名单 + allowedDomains 后缀匹配）。47 个 Hypium 测试（UrlGuard/HttpError/HttpRequest/Call/MockInterceptor）。
- **Harmony NetworkComponent**（`4b462f7`）：`request`（4-method 白名单、envelope/非 envelope 语义、业务失败 = `000000`+`success:false`、守卫命中 → `200007`）+ `getNetworkType`（wifi/cellular/ethernet/none/unknown）+ `network.change` 推送（type|online 去重）。默认 client 的 allowedDomains 与 CoconutSDK.config 引用同步。16 个 Hypium 测试。
- **H5 Network panel**（`e996bee`）：Demo.vue Network 区（GET / POST 501 反例 / getNetworkType / 订阅 network.change）+ Run All 增至 19 项（`coconut.supports` gating，未落地平台显示 skip）；coconut_index.html 三端同步加 Network 按钮组。
- **Android coconut-network JVM 引擎**（`d9d270e`）：Harmony 引擎 1:1 移植为纯 Kotlin JVM 库（零 Android 依赖），双 adapter——默认 `HttpURLConnectionAdapter` + 附赠 `OkHttpAdapter`（okhttp `compileOnly`，宿主自选）。47 个 JVM 单测对标 Harmony + JDK HttpServer 真 HTTP 集成测试（envelope / 501 业务失败 / 非 envelope 直通）+ OkHttp 冒烟。
- **Android NetworkComponent**（`997b4df`）：第 5 个组件注册进 WebBoxApplication。`request` / `getNetworkType` / `network.change`（`registerDefaultNetworkCallback`，type|online 去重）；allowedDomains 与 CoconutSDK 配置 per-request 同步（Kotlin List 不可别名）。模拟器 e2e：coconut_index.html 四组按钮全过 + Demo Run All 19/19（network 3 行 skip → pass）。
- **Android**（`a2a57af`/`8bcb417`）：`OfflineResourceManager` 新增更新 API + 22 个 JVM 测试（compareVersions / 路径守卫 / md5 向量 / staging swap / rollback 真值表）。
- **iOS**（`b1dbba5`/`82f75b1`）：`CoconutUpdateManager.swift`（CryptoKit MD5）+ 15 个 XCTest；HomeViewController 检查更新 / 回滚按钮。
- **Harmony**（`7d7152c`/`9d90203`）：`CoconutUpdateManager.ets` + 19 个 Hypium 测试；Index.ets 按钮 + manifest URL 输入框（须 Mac 局域网 IP，或 `hdc rport tcp:8000 tcp:8000` 后用 127.0.0.1）。
- **HttpClient 一发式 + bytes 模式测试**：`HttpClient.test.ets` 10 个（method/body/params/timeout 透传、rawData 字节级直通、404 错误码、无 envelope 嗅探、AdapterRequest.responseType、mock-bytes 限制钉死）+ 热更新引擎接线 2 个（`useClient(FakeAdapter)`：manifest 404 → unavailable / 正常 manifest → 解析成功且 available）。
- **Android 引擎同款测试**（`1257c3d`）：`HttpClientTest` 10 个（对标 Harmony `HttpClient.test.ets`）+ `HttpURLConnectionAdapterIntegrationTest` bytes 真网络路径（256 字节二进制经 JDK HttpServer 直通）+ `OfflineResourceManagerTest` 引擎接线 2 个（内联 ScriptedAdapter：manifest 404 → unavailable / manifest 200 → 解析成功且走 BYTES 模式）。测试数：coconut-network 54→65、coconut-core 113→115。
- **iOS CoconutNetwork SPM 引擎**（`cd90142`）：两平台引擎对齐移植为独立 Swift 包（纯 Foundation 零依赖；声明 `.macOS(.v13)` 后 `swift test` 宿主机直跑，秒级）。`JSONValue` indirect enum 替代 JsonElement；`HttpConfig` 引用语义 class 供白名单 per-request 同步；adapter 默认 `URLSessionAdapter`（错误按 `URLError.code` 分类）；`MockURLProtocol` stub 替代 JDK HttpServer 集成测试。64 个 XCTest 全绿。
- **iOS NetworkComponent**（`8f28a7b`）：第 5 个组件三端齐活，注册进 SceneDelegate。`request` / `getNetworkType` / `network.change`（`NWPathMonitor` 单流天然合并，type|online 去重）；`NetworkStatusProviding` 测试缝（生产 `NWPathStatusProvider` / 测试 `ManualStatusProvider`）；构造双轨（默认 init 同步 CoconutSDK 白名单 / 测试注入 client+provider）。12 个组件测试。模拟器 e2e：Run All 19/19（network 3 行 skip → pass）+ 热更新五路径（checkUpdate available / performUpdate 应用 v1.0.2 + marker 渲染 / rollback / `--corrupt` MD5 mismatch / 断服重试实测 ~3.1s = 3 次尝试 + 2×1s）。
- **e2e fixture**：`scripts/serve-hot-update.sh`（bump 1.0.1 + 注 marker + 重算哈希；`--corrupt` 篡改哈希供失败路径）。
- 三端 demo 按钮入口（检查更新可用即自动下载应用 / 回滚到内置版本）。

### Changed

- **@coconut/network v1.0.0 → v1.1.0（Harmony，native-first 升级）**：
  - 新增一发式便利 API（`client.request/get/post/put/delete(url, ...)`），内部统一走 `newRequest().buildCall().execute()` 完整管线（拦截器 / UrlGuard / 重试 / header 合并 / mock 短路），native 消费者不再需要两步 builder；此 API 形态为 Android / iOS 引擎后续对齐模板。
  - 新增 bytes 响应模式（`RequestOptions.responseType: HttpResponseType.BYTES`）：传输层 `ARRAY_BUFFER`，`HttpResponse.rawData` 携带原始字节，不做 envelope 嗅探（内容恰为 envelope 形状也直通）；HTTP ≥400 走原错误路径。已知限制：mock 短路不感知 responseType（bytes 请求命中 mock 返回 object data、rawData=null）。
  - 定位明确：引擎 native-first——主要消费者是 native（热更新），`NetworkComponent` 只是 H5 需要时的薄透传。
- **CoconutSDK（Harmony）热更新迁移到引擎**：`CoconutUpdateManager` 删除裸 `http.createHttp()` 下载，改走 `@coconut/network`（新增 `file:../CoconutNetwork` HAR→HAR 依赖）——自动获得重试（2 次 / 1s 间隔）/ UrlGuard / 统一超时（默认值与原 15s/30s 一致）；新增 `useClient()` 注入钩子（测试接线 FakeAdapter / 宿主共享 client）。行为差异：旧实现严拒非 200，迁移后接受任意 2xx 且有 body 的响应（204 → rawData null → 判失败）；fixture（python http.server）无影响。
- **coconut-network v1.0.0 → v1.1.0（Android，对齐 Harmony）**（`1257c3d`）：同款一发式便利 API + bytes 响应模式（`RequestOptions(responseType = HttpResponseType.BYTES)` → `HttpResponse.rawData: ByteArray?` 字节直通，无 envelope 嗅探；双 adapter 均支持）；Kotlin 侧用 data class `copy()` 合并 options（无 ArkTS 手写 mergeOptions 之痛）。两平台引擎 API 至此对齐，iOS 后续按此模板。
- **Android 热更新迁移到引擎**（`c71efab`）：`OfflineResourceManager` 删除裸 `HttpURLConnection` 下载（`downloadToFile` 流拷贝 → `downloadBytes` bytes 模式一次拿全量），`coconut-core` 新增 `api(project(":coconut-network"))` 依赖——自动获得重试 / UrlGuard / 统一超时；同款 `useClient()` 注入钩子。行为差异同 Harmony（严拒非 200 → 接受任意 2xx 且非空 body）。模拟器 e2e 五路径全过：checkUpdate available / performUpdate 应用 v1.0.2 + marker 渲染 / rollback 回内置包 / `--corrupt` MD5 mismatch（staging 清理、旧包完好）/ 断服失败路径（引擎重试实测：连接拒绝场景 ~2s = 3 次尝试 + 2×1s 间隔）。
- **iOS 热更新迁移到引擎**（`ea53c1f`）：`CoconutUpdateManager` 删除裸 `URLSession.data` ×2，改走 CoconutNetwork bytes 模式，CoconutSDK 新增包依赖——自动获得重试 / UrlGuard / 错误分类；同款 `useClient()` 注入钩子。行为差异（更严）：旧实现不查 HTTP 状态码（404 错误页也当数据收），迁移后 ≥400 直接失败（404 manifest → "资源不存在"）。CoconutSDKTests +4 wiring 用例（注入 ScriptedAdapter），102→106。
- 删除 Android 休眠的 zip 热更新路径（`dd30092`）—— 单一机制（逐文件），git 可找回。

### Fixed

- **离线包 demo Vue app 从未渲染（三端，自 `7fa83d9` 起）**：vite iife bundle 结尾立即 `.mount('#app')`，而入口 script 被 `build-offline-package.sh` 剥成 classic script 后位于 `<head>`，执行时 `<body>`（含 `#app`）尚未解析 → 挂载失败、页面空白（纯 HTML 的热更新 marker 能显示，故此前 e2e 未暴露；2026-08-20 Harmony 热更新 e2e 复查渲染时抓到）。修复：`coconutWebBox/src/main.js` 等 `DOMContentLoaded` 再挂载（`readyState` 已就绪则立即挂，dev server 场景不受影响），H5 版本 1.0.0 → 1.0.1，三端产物重建分发（`--check` 三端一致），Harmony 模拟器验证离线包页面完整渲染（env / capabilities 面板）。
- **Harmony NetworkComponent 真机全废**（2026-08-20 真机验证抓到，模拟器未暴露）：`hasDefaultNet`/`getDefaultNet`/`getNetCapabilities` 是 ACL 权限 API，debug profile 的 `allowed-acls` 不背书时恒抛 201（被静默 catch 吞掉 → `getNetworkType` 恒报 `none`）——之前记录的"模拟器怪癖"实为同一 bug。修复：改为 `NetConnection` 事件流驱动（register/netAvailable/netLost/netCapabilitiesChange 不受 ACL 限制，宿主无需申 ACL），拉取式 API 仅作冷启动兜底（保留 error 日志可诊断）；`netAvailable` 延迟 150ms 合并推送防双发；补 `netLost` 监听（部分版本断网不触发 `netUnavailable`）；`module.json5` 补声明 `GET_NETWORK_INFO`。真机（MatePad Pro / HarmonyOS 6.1）验证：getNetworkType 报真实 bearer + 断网/重连双向推送；Hypium 225/225。
- Harmony manifest 解析不容忍 pretty-print JSON（`"key": "value"` 带空格）→ 空白容忍正则 + 回归测试（e2e 抓到，单测漏网）。
- Harmony `fileIo.mkdirSync` 目标已存在时抛 "File exists"（recursive=true 也抛）→ 全部建目录走守卫 `ensureDir`，否则 performUpdate 首个根级文件即失败、version.json 永不落盘（e2e 抓到）。
- Harmony `cryptoFramework` MD5 在部分模拟器镜像 HUKS 层失败 → 纯 JS RFC 1321 实现（已知向量钉死）。
- **iOS SceneDelegate e2e 钩子拼 baseUrl 用 `NSString.deletingLastPathComponent`**：该 API 是路径语义，会把 `http://` 折叠成 `http:/`——旧裸 URLSession 容忍，引擎 UrlGuard 正确拒绝（`missing or invalid scheme`），热更新 e2e 抓到。改为手动截最后一个 `/` 之后的段。

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
