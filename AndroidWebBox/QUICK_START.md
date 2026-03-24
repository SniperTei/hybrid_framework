# AndroidWebBox 快速入门指南

## 5分钟上手

### 步骤1: 项目初始化

项目已经包含以下核心模块：
- `hybrid-sdk/` - 框架SDK（可作为独立Library使用）
- `app/` - 示例应用

### 步骤2: 运行项目

```bash
# 连接Android设备或启动模拟器
./gradlew installDebug

# 或者使用Android Studio直接运行
```

### 步骤3: 测试功能

应用启动后，你将看到一个漂亮的测试页面，包含以下功能：

| 功能 | 说明 |
|------|------|
| 📱 设备信息 | 获取手机型号、系统版本等 |
| 📷 拍照 | 调用相机拍照 |
| 🖼️ 相册选择 | 选择单张/多张图片或视频 |
| 🎥 录像 | 录制视频（最长60秒） |

点击任意按钮即可测试对应功能。

## 项目结构说明

```
AndroidWebBox/
├── hybrid-sdk/                          # 框架SDK
│   ├── core/                            # 核心模块
│   │   ├── JSBridge.kt                  # JSBridge双向通信
│   │   ├── WebContainer.kt              # 增强的WebView容器
│   │   ├── PluginManager.kt             # 插件管理器
│   │   └── HybridConfig.kt              # 配置类
│   │
│   ├── plugin/                          # 插件系统
│   │   ├── HybridPlugin.kt              # 插件接口
│   │   ├── BasePlugin.kt                # 插件基类
│   │   ├── PluginContext.kt             # 插件上下文
│   │   └── PluginCallback.kt            # 回调接口
│   │
│   └── plugins/                         # 内置插件
│       ├── CameraPlugin.kt              # 相机插件
│       ├── GalleryPlugin.kt             # 相册插件
│       ├── VideoPlugin.kt               # 录像插件
│       └── DevicePlugin.kt              # 设备信息插件
│
├── app/                                 # 示例应用
│   └── src/main/
│       ├── java/com/sniper/webbox/
│       │   └── MainActivity.kt          # 使用示例
│       ├── res/
│       │   └── xml/file_paths.xml       # FileProvider配置
│       └── assets/
│           └── index.html               # H5测试页面
│
├── README.md                            # 项目说明
├── ARCHITECTURE.md                      # 架构设计文档
├── API.md                               # API详细文档
└── QUICK_START.md                       # 本文件
```

## 核心概念

### 1. WebContainer (WebView容器)

增强版的WebView，负责：
- 加载H5页面
- 管理WebView配置
- 处理页面生命周期
- 与JSBridge集成

### 2. JSBridge (双向通信)

连接H5和Native的桥梁：
- H5 → Native: 调用原生功能
- Native → H5: 返回结果、推送事件

### 3. Plugin (插件系统)

每个原生功能都是一个插件：
- **CameraPlugin**: 相机拍照
- **GalleryPlugin**: 相册选择
- **VideoPlugin**: 视频录制
- **DevicePlugin**: 设备信息

## JavaScript API示例

### 拍照

```javascript
AndroidWebBox.camera.capture({
    quality: 80  // 图片质量1-100
}, function(response) {
    if (response.success) {
        console.log('照片路径:', response.data.path);
        console.log('照片URI:', response.data.uri);
    } else {
        console.error('错误:', response.error.message);
    }
});
```

### 选择图片

```javascript
// 单选
AndroidWebBox.gallery.pick({
    multiple: false,
    max_count: 1,
    media_type: 'image'
}, callback);

// 多选
AndroidWebBox.gallery.pick({
    multiple: true,
    max_count: 9,
    media_type: 'image'
}, function(response) {
    if (response.success) {
        response.data.files.forEach(file => {
            console.log(file.path);
        });
    }
});
```

### 获取设备信息

```javascript
AndroidWebBox.device.getInfo(function(response) {
    if (response.success) {
        console.log('App版本:', response.data.appVersion);
        console.log('设备型号:', response.data.model);
        console.log('系统版本:', response.data.systemVersion);
        console.log('屏幕尺寸:', response.data.screenWidth + 'x' + response.data.screenHeight);
    }
});
```

## 自定义插件

### 1. 创建插件类

```kotlin
// 在hybrid-sdk/src/main/java/com/sniper/hybrid/plugins/下创建
class SharePlugin : BasePlugin() {

    override fun pluginName() = "share"

    override fun exec(action: String, params: JSONObject, callback: PluginCallback) {
        when (action) {
            "shareText" -> shareText(params, callback)
            "shareImage" -> shareImage(params, callback)
            else -> callback.error("UNKNOWN_ACTION", "Unknown action")
        }
    }

    private fun shareText(params: JSONObject, callback: PluginCallback) {
        val text = optString(params, "text", "")
        // 实现分享逻辑
        callback.success(mapOf("shared" to true))
    }

    private fun shareImage(params: JSONObject, callback: PluginCallback) {
        val imagePath = optString(params, "path", "")
        // 实现图片分享逻辑
        callback.success(mapOf("shared" to true))
    }
}
```

### 2. 注册插件

在`MainActivity.kt`中：

```kotlin
webContainer.getPluginManager().registerPlugin(SharePlugin())
```

### 3. 在H5中调用

```javascript
AndroidWebBox.share.shareText({
    text: "Hello from AndroidWebBox!"
}, function(response) {
    if (response.success) {
        console.log('分享成功');
    }
});
```

## 常见配置

### 开启调试模式

```kotlin
val config = HybridConfig.Builder()
    .setDefaultUrl("file:///android_asset/index.html")
    .setDebugMode(true)  // 开启调试日志
    .build()
```

### 设置域名白名单

```kotlin
val config = HybridConfig.Builder()
    .setAllowedDomains(listOf(
        "example.com",
        "api.example.com"
    ))
    .build()
```

### 自定义UserAgent

```kotlin
val config = HybridConfig.Builder()
    .setUserAgent("MyApp/1.0 (Android)")
    .build()
```

## 调试技巧

### 1. 查看日志

```bash
adb logcat | grep -E "PluginManager|JSBridge|WebContainer"
```

### 2. Chrome DevTools

```bash
# Chrome浏览器中访问
chrome://inspect
```

### 3. 查看网络请求

使用`Charles`或`Fiddler`抓包工具。

## 注意事项

### 权限处理

Android 6.0+需要运行时权限，框架已内置权限处理逻辑：

```kotlin
// 在AndroidManifest.xml中声明
<uses-permission android:name="android.permission.CAMERA" />

// 框架会自动请求运行时权限
```

### 文件访问

Android 10+使用了分区存储，建议使用URI访问文件：

```javascript
AndroidWebBox.camera.capture({}, function(response) {
    if (response.success) {
        // 使用URI而不是直接路径
        const uri = response.data.uri;
        // 显示图片
        document.getElementById('img').src = uri;
    }
});
```

### 内存管理

记得在Activity销毁时清理资源：

```kotlin
override fun onDestroy() {
    webContainer.destroy()
    super.onDestroy()
}
```

## 进阶使用

### 事件监听

```javascript
// 监听App生命周期
AndroidWebBox.event.on('resume', function() {
    console.log('App恢复');
});

AndroidWebBox.event.on('pause', function() {
    console.log('App暂停');
});
```

### 自定义WebView配置

```kotlin
webContainer.setUrlInterceptor { url ->
    // 拦截特定URL
    if (url.startsWith("custom://")) {
        handleCustomUrl(url)
        return@setUrlInterceptor true
    }
    false
}
```

## 下一步

- 📖 阅读 [API文档](API.md) 了解完整API
- 🏗️ 查看 [架构设计](ARCHITECTURE.md) 了解框架原理
- 🔌 尝试开发自定义插件

## 常见问题

**Q: 如何加载远程H5页面？**

A: 修改配置中的`defaultUrl`：
```kotlin
setDefaultUrl("https://example.com/index.html")
```

**Q: 如何添加新的内置插件？**

A: 参考`CameraPlugin`的实现，继承`BasePlugin`并在`MainActivity`中注册。

**Q: 如何调试H5页面？**

A: 使用Chrome DevTools：`chrome://inspect`，确保开启`debugMode`。

**Q: 支持哪些Android版本？**

A: 最低支持Android 10 (API 29)，推荐Android 13+。

## 获取帮助

- 查看文档：README.md, API.md, ARCHITECTURE.md
- 查看示例代码：app/src/main/java/com/sniper/webbox/MainActivity.kt
- 查看测试页面：app/src/main/assets/index.html

祝你使用愉快！🚀
