# Coconut SDK 集成完成

## 项目结构

```
AndroidWebBox/
├── app/                          # 主应用模块（持有全部组件源码）
│   └── src/main/java/com/sniper/androidwebbox/
│       ├── WebBoxApplication.kt  # 在此显式注册组件
│       └── components/           # 通用参考组件 + 业务组件
│           ├── device/DeviceComponent.kt
│           ├── network/NetworkComponent.kt
│           ├── storage/StorageComponent.kt
│           ├── event/EventComponent.kt
│           ├── dialog/DialogComponent.kt
│           └── LoginComponent.kt  # 业务组件示例
│
├── coconut-core/                 # 核心模块（Bridge / Component / Security）
│   ├── src/main/java/com/sniper/coconut/
│   │   ├── bridge/               # Bridge系统
│   │   │   ├── CoconutBridge.kt
│   │   │   ├── CoconutBridgeImpl.kt
│   │   │   └── model/            # JSON-RPC 2.0 请求/响应模型
│   │   ├── component/            # 组件系统
│   │   │   ├── CoconutPlugin.kt   # 组件接口
│   │   │   ├── BaseComponent.kt   # 组件基类
│   │   │   ├── ComponentManager.kt
│   │   │   ├── ComponentContext.kt
│   │   │   └── ComponentMetadata.kt
│   │   └── utils/
│   │       └── Logger.kt
│   └── build.gradle.kts
│
└── coconut-sdk/                  # SDK统一入口模块（初始化 + WebView 封装）
    ├── src/main/java/com/sniper/coconut/
    │   ├── CoconutSDK.kt        # 主入口API
    │   ├── config/CoconutConfig.kt
    │   ├── resource/ResourceManager.kt
    │   └── web/CoconutWebViewHelper.kt
    └── build.gradle.kts
```

## 模块依赖关系

```
app (持有组件源码)
  ↓ 依赖
coconut-sdk
  ↓ 依赖
coconut-core
```

> CoconutSDK 只放框架（Bridge / ComponentManager / 安全管线），**不含任何具体组件**。组件归 App 装配，通过显式注册决定启用哪些。

## 如何使用

### 1. 在app模块中引用

```kotlin
// app/build.gradle.kts
dependencies {
    implementation(project(":coconut-sdk"))
}
```

### 2. 初始化SDK

```kotlin
class MyApplication : Application() {
    private val applicationScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    override fun onCreate() {
        super.onCreate()

        // 初始化Coconut SDK
        CoconutSDK.initialize(this)

        // 配置SDK
        CoconutSDK.configure {
            setDebugMode(true)
            setTimeout(30000)
        }

        // 显式注册组件（三端统一模式）
        applicationScope.launch {
            CoconutSDK.registerComponents(
                DeviceComponent(),
                NetworkComponent(),
                StorageComponent()
                // ... 按需添加更多组件
            )
        }
    }
}
```

### 3. 在Activity中使用

```kotlin
class MyActivity : AppCompatActivity() {
    private lateinit var bridge: CoconutBridgeImpl

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val webView = WebView(this)
        bridge = CoconutBridgeImpl(ComponentManager.getInstance())

        webView.addJavascriptInterface(
            object {
                @JavascriptInterface
                fun call(jsonData: String): String {
                    return bridge.handleCall(webView, jsonData)
                }
            },
            "CoconutBridge"
        )
    }
}
```

### 4. H5端调用

页面引入 `coconut.js`（随 SDK 分发，见 `app/src/main/assets/`）后，用全局小写 `coconut`，error-first callback 风格：

```javascript
// 调用设备组件
coconut.call('device', 'getInfo', {}, (err, data) => {
    if (err) { console.error(err.message); return; }
    console.log(JSON.stringify(data));
});

// 调用网络组件（原生 HTTP 请求 / 网络状态）
coconut.call('network', 'getNetworkType', {}, (err, data) => {
    if (err) { console.error(err.message); return; }
    console.log(data.type, data.online);   // 如 'wifi' true
});

// 调用存储组件
coconut.call('storage', 'setItem', { key: 'myKey', value: 'myValue' }, (err, data) => {
    if (err) { console.error(err.message); return; }
    console.log(data);
});

// 容器导航（v3.5.0，需宿主注册 NavigatorComponent）
coconut.navigator.forward(
    { url: '/order/detail', params: { id: 123 }, header: { title: '订单详情' } },
    (err, data) => { if (err) { console.error(err.message); return; } }
);
coconut.on('nav.result', ({ result }) => { /* 子容器 close({result}) 回传 */ });
```

组件/方法名以 `API_CONTRACT.md`（仓库根，唯一权威）为准；H5 侧可用 `coconut.supports(component, fn)` 同步探测当前宿主是否启用某方法。

## 构建命令

```bash
# 构建所有模块
./gradlew build

# 只构建SDK模块
./gradlew :coconut-core:build
./gradlew :coconut-sdk:build

# 构建并安装app
./gradlew :app:installDebug

# 发布到Maven本地
./gradlew publishToMavenLocal
```

## 技术栈

- **Kotlin**: 2.0.21
- **Android Gradle Plugin**: 8.13.2
- **Kotlin Coroutines**: 1.7.3
- **Kotlin Serialization**: 1.6.0
- **OkHttp**: 4.12.0 (NetworkComponent 的 HTTP 后端之一，可选)
- **Compile SDK**: 36
- **Min SDK**: 29

## 命名重构对照表

| 旧名称 | 新名称 |
|--------|--------|
| HybridPlugin | CoconutPlugin (接口) |
| BasePlugin | BaseComponent |
| PluginManager | ComponentManager |
| PluginContext | ComponentContext |
| PluginMetadata | ComponentMetadata |
| JSBridgeInterface | CoconutBridge |
| JSBridgeImpl | CoconutBridgeImpl |
| DevicePlugin | DeviceComponent |
| NetworkPlugin | NetworkComponent |
| StorageComponent | StorageComponent (保持) |

## 状态

1. ✅ 项目结构创建完成
2. ✅ 所有模块构建成功
3. ✅ 依赖配置正确
4. ✅ app 模块中包含全部组件源码与示例注册
5. ✅ H5 测试页面（`coconut_index.html`）就绪
6. ✅ 三端架构对齐（iOS / Android / Harmony 组件均在 App 工程）

## 注意事项

1. **Java版本**: 所有模块使用Java 17
2. **包名约定**:
   - 框架代码：`com.sniper.coconut.*`（coconut-core / coconut-sdk）
   - App 组件代码：`com.sniper.androidwebbox.components.*`（业务自定义）
3. **命名空间**:
   - coconut-core: `com.sniper.coconut.core`
   - coconut-sdk: `com.sniper.coconut.sdk`
4. **组件注册**：显式注册模式（三端统一），不扫描注解。App 决定启用哪些组件。
5. **权限要求**:
   - 网络相关组件需要 INTERNET 权限
   - app模块需要在AndroidManifest.xml中声明所需权限
