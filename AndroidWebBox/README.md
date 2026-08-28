# CoconutSDK (Android)

> Android 端 CoconutSDK —— 两个 Gradle 模块：`coconut-core`（纯框架）+ `coconut-sdk`（入口 + WebView 封装）。
> 最低支持 Android API 24。使用系统 `WebView`（Chromium-based）。

跨平台架构、Bridge 协议、错误码、安全机制详见仓库根 [`ARCHITECTURE.md`](../ARCHITECTURE.md) 和 [`API_CONTRACT.md`](../API_CONTRACT.md)。本 README 只介绍 Android 端的结构、API、用法。集成到自己的 App 见 [`COCONUT_SDK_INTEGRATION.md`](./COCONUT_SDK_INTEGRATION.md)。

---

## 模块结构

Android 端把 CoconutSDK 拆成两个 Gradle 模块：

| 模块 | 角色 | 内容 |
|------|------|------|
| `coconut-core` | **纯框架**（不依赖 WebView） | Bridge / Component / Security / Logger |
| `coconut-sdk` | **SDK 入口 + WebView 封装** | CoconutSDK 单例、CoconutWebActivity、资源管理 |

> 为什么拆？
> `coconut-core` 可以**纯 JVM 单元测试**（不需要 Robolectric 或真机），覆盖 137 个 case。WebView 相关的封装（`CoconutWebActivity` 等）放 `coconut-sdk`，因为它们需要 `Context` 和 `WebView` 实例。

```
AndroidWebBox/
├── coconut-core/                                # 框架（可 JVM 测试）
│   └── src/main/java/com/sniper/coconut/
│       ├── bridge/
│       │   ├── CoconutBridge.kt                 # 协议（call/cleanup 等抽象）
│       │   ├── CoconutBridgeImpl.kt             # @JavascriptInterface 实现（同步）
│       │   ├── BridgeSecurityValidator.kt       # 域名白名单 + 限流 + params 大小
│       │   ├── BridgeTokenManager.kt            # UUID 会话令牌
│       │   ├── BridgePerformance.kt             # 调用耗时统计
│       │   ├── SecurityAuditLog.kt              # 安全事件审计
│       │   └── model/
│       │       ├── BridgeRequest.kt             # JSON-RPC 请求模型
│       │       └── BridgeResponse.kt            # 响应模型（含 ErrorCode）
│       ├── component/
│       │   ├── CoconutPlugin.kt                 # 组件接口
│       │   ├── BaseComponent.kt                 # 抽象基类（含 param helpers）
│       │   ├── ComponentContext.kt              # 上下文（Application / Logger / 资源）
│       │   ├── ComponentHost.kt                 # 组件宿主
│       │   ├── ComponentManager.kt              # 注册、路由、生命周期
│       │   ├── ComponentMetadata.kt             # 注解元数据（保留兼容，新代码用显式注册）
│       │   └── ActivityForResultDispatcher.kt   # 组件 startActivityForResult 调度
│       ├── resource/
│       │   ├── CoconutResourceHolder.kt         # 资源持有
│       │   └── OfflineResourceManager.kt        # 离线包 + 热更新管理
│       ├── nav/                                 # 容器导航（v3.5.0）
│       │   ├── NavConfig.kt                     # 导航栏配置（三级合并链）
│       │   └── TemplateRegistry.kt              # 模板容器注册表（assets/coconut_templates.json）
│       └── utils/
│           └── Logger.kt
│
├── coconut-sdk/                                 # 入口 + WebView 封装
│   └── src/main/java/com/sniper/coconut/
│       ├── CoconutSDK.kt                        # SDK 单例入口（initialize / configure / registerComponents）
│       ├── config/
│       │   ├── CoconutConfig.kt                 # 配置（debugMode / environment / 开关 / nav）
│       │   └── Environment.kt                   # DEV / STAGING / PROD
│       ├── resource/
│       │   └── ResourceManager.kt
│       └── web/
│           ├── CoconutWebActivity.kt            # 现成 Activity：WebView 装配 + 全套 bridge + 导航栏 + 错误弹窗（可继承做模板容器）
│           ├── CoconutWebViewHelper.kt          # WebView 配置（缓存 / UserAgent / 等）
│           ├── NavResultBus.kt                  # close({result}) 单槽回传（v3.5.0）
│           └── WebViewSecurityConfig.kt         # HTTPS / file access 安全配置
│
└── app/                                         # 宿主 App（持有 6 个组件）
    └── src/main/java/com/sniper/androidwebbox/
        ├── WebBoxApplication.kt                 # 注册组件入口 + 模板 eager 校验
        ├── DemoTemplateActivity.kt              # 模板容器示范（继承 CoconutWebActivity，注册名 "demo"）
        └── components/                          # 6 个组件（各一子包）+ 业务组件
            ├── device/ ├── storage/ ├── event/ ├── dialog/ ├── network/
            └── navigator/                       # NavigatorComponent：forward / back / backToTop / close
```

> **组件不在 SDK 内**。框架不含任何业务组件，所有组件都在宿主 App `app/src/.../components/` 下，App 决定启用哪些。

---

## 核心 API

### `CoconutSDK`（单例 object）

```kotlin
// 1. 初始化（通常在 Application.onCreate）
CoconutSDK.initialize(this)

// 2. 配置
CoconutSDK.configure {
    isDebugMode = true
    environment = Environment.DEV
    enableBridgeToken = true       // 默认 true
    allowedDomains = listOf("example.com")
}

// 3. 注册组件（suspend，通常在 Application.onCreate 协程里调）
CoconutSDK.registerComponents(
    DeviceComponent(),
    StorageComponent(),
    EventComponent(),
    DialogComponent(),
    NetworkComponent(),
    NavigatorComponent()
    // ... + 业务组件按需添加
)

// 4. 清理（App 退出时）
CoconutSDK.cleanup()
```

### `CoconutWebActivity`

现成的 Activity：内部创建 WebView、注入 coconut.js、注册 `@JavascriptInterface`、加载 URL。

```kotlin
val intent = CoconutWebActivity.intent(context, "https://example.com")
startActivity(intent)
```

也可以**不用这个 Activity**——如果你有自己的 WebView 容器，直接调 `CoconutSDK.initialize` + 把 `CoconutBridgeImpl` 通过 `addJavascriptInterface` 注册到自己的 WebView。

---

## 写一个自定义组件

```kotlin
class EchoComponent : BaseComponent() {
    override val name = "echo"
    override val version = "1.0.0"

    override suspend fun handle(
        function: String,
        paramsJson: String
    ): BridgeResponse {
        return when (function) {
            "ping" -> {
                // getParam / getIntParam / getBoolParam 是 BaseComponent 的 helper
                val msg = getParam(paramsJson, "message", defaultValue = "pong")
                BridgeResponse.success(result = """{"echo":"$msg"}""")
            }
            else -> throw ComponentException.functionNotFound(function)
        }
    }
}
```

注册到 `CoconutSDK.registerComponents(..., EchoComponent())` 之后，H5 就能调用：
```js
const r = await CoconutBridge.call('echo.ping', { message: 'hi' });
// r.result === { echo: 'hi' }
```

---

## Bridge 模式（Android 同步）

Android `WebView` 的 `@JavascriptInterface` 方法**支持同步返回**——JS 调用线程阻塞等结果。所以 Android Bridge 走：

```
H5: AndroidBridge.call(jsonRpcRequest)
   ↓ 阻塞
CoconutBridgeImpl.call(request): String
   ↓
3 层安全校验 → ComponentManager 路由 → 组件 handle
   ↓
return jsonResponse  // 同步返回 JSON 字符串
   ↓
H5: 拿到 JSON，Promise resolve
```

> ⚠️ 因为是同步阻塞，**绝对不能在 handle 里直接做长耗时操作**（如网络请求）。要么用协程 + suspend 函数让 BridgeImpl 内部 await，要么把任务甩到其他线程后通过回调返回。

---

## 测试

```bash
cd AndroidWebBox
./gradlew :coconut-core:testDebugUnitTest
# 137 个 case，~2s
```

测试覆盖：Bridge 模型 / 安全管线（Token / Security / Audit / Performance） / Component 系统。

**只测 `coconut-core`**：所有 `coconut-sdk` 类都需要 `Context` 或 `WebView`，无法纯 JVM 测，属于 instrumented test 范畴。

测试细节：
- `testOptions.unitTests.isReturnDefaultValues = true` 让 `android.util.Log` 桩返回默认值不抛错
- MockK relaxed Context + 稳定的 SupervisorJob scope 给 ComponentManager
- `BridgeSecurityValidator` 未覆盖 —— 用了 `android.net.Uri.parse()`，需要重构成 `java.net.URI` 或加 Robolectric

---

## 集成到自己的 Android App

详见 [`COCONUT_SDK_INTEGRATION.md`](./COCONUT_SDK_INTEGRATION.md) —— 包含 Gradle 依赖配置、混淆规则、权限要求、最小化集成 demo。
