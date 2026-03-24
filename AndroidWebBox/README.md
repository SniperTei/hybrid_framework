# AndroidWebBox

一个轻量级、可扩展的Android混合开发框架。

## 特性

- 🎯 **简单易用** - 几行代码即可集成
- 🔌 **插件化** - 模块化插件系统，按需扩展
- 🌉 **JSBridge** - 双向通信，Promise风格API
- 📱 **原生功能** - 相机、相册、录像、设备信息等
- 🔒 **安全可靠** - 域名白名单、权限管理
- 📦 **独立SDK** - 可作为Library复用到多个项目

## 快速开始

### 1. 添加依赖

在`settings.gradle.kts`中：

```kotlin
include(":app")
include(":hybrid-sdk")
```

在`app/build.gradle.kts`中：

```kotlin
dependencies {
    implementation(project(":hybrid-sdk"))
}
```

### 2. 配置权限

在`AndroidManifest.xml`中添加所需权限：

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<!-- 根据需要添加其他权限 -->
```

### 3. 使用WebContainer

```kotlin
class MainActivity : AppCompatActivity() {
    private lateinit var webContainer: WebContainer

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 创建并配置WebContainer
        webContainer = WebContainer(this)

        val config = HybridConfig.Builder()
            .setDefaultUrl("file:///android_asset/index.html")
            .setDebugMode(true)
            .build()

        webContainer.init(config, this)

        // 注册插件
        webContainer.getPluginManager().registerPlugins(listOf(
            CameraPlugin(),
            GalleryPlugin(),
            VideoPlugin(),
            DevicePlugin()
        ))

        // 设置为主视图并加载
        setContentView(webContainer)
        webContainer.loadUrl(config.defaultUrl)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        webContainer.onActivityResult(requestCode, resultCode, data)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        webContainer.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
}
```

### 4. 在H5中调用

```javascript
// 等待SDK初始化完成
if (window.AndroidWebBox) {
    // 调用原生功能
    AndroidWebBox.camera.capture({
        quality: 80
    }, function(response) {
        if (response.success) {
            console.log('照片路径:', response.data.path);
        } else {
            console.error('错误:', response.error);
        }
    });
}
```

## 内置插件

| 插件 | 功能 |
|------|------|
| Camera | 拍照 |
| Gallery | 选择图片/视频 |
| Video | 录制视频 |
| Device | 获取设备信息 |

## 自定义插件

```kotlin
class MyPlugin : BasePlugin() {
    override fun pluginName() = "myPlugin"

    override fun exec(action: String, params: JSONObject, callback: PluginCallback) {
        callback.success(mapOf("result" to "Hello"))
    }
}

// 注册
webContainer.getPluginManager().registerPlugin(MyPlugin())

// 在H5中调用
// AndroidWebBox.myPlugin.myAction({}, callback);
```

## 项目结构

```
AndroidWebBox/
├── hybrid-sdk/              # 框架SDK核心
│   ├── core/               # 核心功能
│   ├── plugin/             # 插件系统
│   └── plugins/            # 内置插件
│
├── app/                    # 示例应用
│   └── src/main/assets/    # H5资源
│
├── ARCHITECTURE.md         # 架构设计文档
└── API.md                  # API详细文档
```

## 文档

- [架构设计](ARCHITECTURE.md) - 框架架构和设计理念
- [API文档](API.md) - JavaScript API详细说明

## 技术栈

- Kotlin
- Android WebView
- Coroutines
- kotlinx.serialization

## 优势

1. **轻量级** - 核心SDK体积小，不依赖大型框架
2. **可扩展** - 插件化架构，易于添加新功能
3. **类型安全** - Kotlin编写，空安全
4. **现代化** - 使用最新的Android API
5. **可复用** - SDK独立，可在多个项目中使用

## Roadmap

- [ ] 更多内置插件（定位、分享、文件管理等）
- [ ] 支持Cordova/Capacitor插件兼容
- [ ] 完善的单元测试
- [ ] 性能优化和内存管理增强
- [ ] 支持热更新

## 贡献

欢迎提交Issue和Pull Request！

## 许可证

MIT License
