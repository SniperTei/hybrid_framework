# Coconut SDK 集成完成

## 项目结构

```
AndroidWebBox/
├── app/                          # 主应用模块
│   └── build.gradle.kts          # 依赖 :coconut-sdk
│
├── coconut-core/                 # 核心模块 (10个Kotlin文件)
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
├── coconut-plugins/              # 内置组件模块 (3个Kotlin文件)
│   ├── src/main/java/com/sniper/coconut/components/
│   │   ├── device/DeviceComponent.kt    # 设备信息
│   │   ├── network/NetworkComponent.kt  # 网络状态
│   │   └── storage/StorageComponent.kt  # 本地存储
│   └── build.gradle.kts
│
└── coconut-sdk/                  # SDK统一入口模块 (4个Kotlin文件)
    ├── src/main/java/com/sniper/coconut/
    │   ├── CoconutSDK.kt        # 主入口API
    │   ├── config/CoconutConfig.kt
    │   ├── resource/ResourceManager.kt
    │   └── web/CoconutWebViewHelper.kt
    └── build.gradle.kts
```

## 模块依赖关系

```
app
  ↓ 依赖
coconut-sdk
  ↓ 依赖
coconut-core + coconut-plugins
```

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
    override fun onCreate() {
        super.onCreate()

        // 初始化Coconut SDK
        CoconutSDK.initialize(this)

        // 配置SDK
        CoconutSDK.configure {
            setDebugMode(true)
            setTimeout(30000)
        }

        // 注册组件
        lifecycleScope.launch {
            CoconutSDK.registerComponents(
                DeviceComponent(),
                NetworkComponent(),
                StorageComponent()
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

```javascript
// 调用设备组件
Coconut.call('device.getInfo', {}, function(response) {
    console.log(response.result);
});

// 调用网络组件
Coconut.call('network.getState', {}, function(response) {
    console.log(response.result);
});

// 调用存储组件
Coconut.call('storage.setItem', { key: 'myKey', value: 'myValue' }, function(response) {
    console.log(response.result);
});
```

## 构建命令

```bash
# 构建所有模块
./gradlew build

# 只构建SDK模块
./gradlew :coconut-core:build
./gradlew :coconut-plugins:build
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
- **ClassGraph**: 4.8.162 (组件自动扫描)
- **Compile SDK**: 34
- **Min SDK**: 24

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

## 下一步

1. ✅ 项目结构创建完成
2. ✅ 所有模块构建成功
3. ✅ 依赖配置正确
4. ⏭️ 在app模块中创建示例代码
5. ⏭️ 创建H5测试页面
6. ⏭️ 编写集成文档

## 注意事项

1. **Java版本**: 所有模块使用Java 17
2. **包名**: `com.sniper.coconut.*`
3. **命名空间**:
   - coconut-core: `com.sniper.coconut.core`
   - coconut-plugins: `com.sniper.coconut.components`
   - coconut-sdk: `com.sniper.coconut.sdk`
4. **权限要求**:
   - coconut-plugins需要网络权限
   - app模块需要在AndroidManifest.xml中配置网络权限
