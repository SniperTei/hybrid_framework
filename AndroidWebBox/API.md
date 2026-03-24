# AndroidWebBox API 文档

## 概述

AndroidWebBox是一个轻量级、可扩展的Android混合开发框架，允许H5页面调用原生功能。

## 快速开始

### 1. 在Native端配置

```kotlin
class MainActivity : AppCompatActivity() {
    private lateinit var webContainer: WebContainer

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 创建WebContainer
        webContainer = WebContainer(this)

        // 创建配置
        val config = HybridConfig.Builder()
            .setDefaultUrl("file:///android_asset/index.html")
            .setDebugMode(true)
            .build()

        // 初始化
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
}
```

### 2. 在H5端调用

```javascript
// 等待SDK初始化
if (window.AndroidWebBox) {
    // 调用原生功能
    AndroidWebBox.camera.capture({}, function(response) {
        if (response.success) {
            console.log('照片路径:', response.data.path);
        }
    });
}
```

## JavaScript API

### Camera (相机)

#### 拍照
```javascript
AndroidWebBox.camera.capture({
    quality: 80  // 图片质量 1-100，默认80
}, function(response) {
    if (response.success) {
        console.log(response.data.path);  // 本地路径
        console.log(response.data.uri);   // URI
    }
});
```

**返回数据：**
```json
{
    "path": "/storage/emulated/0/.../IMG_20240101_120000.jpg",
    "uri": "content://..."
}
```

### Gallery (相册)

#### 选择图片/视频
```javascript
// 单选图片
AndroidWebBox.gallery.pick({
    multiple: false,
    max_count: 1,
    media_type: 'image'  // 'image', 'video', 'all'
}, callback);

// 多选图片
AndroidWebBox.gallery.pick({
    multiple: true,
    max_count: 9,
    media_type: 'image'
}, callback);
```

**返回数据（单选）：**
```json
{
    "uri": "content://...",
    "path": "/storage/..."
}
```

**返回数据（多选）：**
```json
{
    "files": [
        {"uri": "...", "path": "..."},
        {"uri": "...", "path": "..."}
    ]
}
```

### Video (录像)

#### 录制视频
```javascript
AndroidWebBox.video.record({
    max_duration: 60,  // 最长时长（秒），0表示无限制
    quality: 1         // 0=低质量, 1=高质量
}, function(response) {
    if (response.success) {
        console.log(response.data.path);
        console.log(response.data.size_mb);
    }
});
```

**返回数据：**
```json
{
    "path": "/storage/emulated/0/.../VID_20240101_120000.mp4",
    "uri": "content://...",
    "size": 1048576,
    "size_mb": "1.00"
}
```

### Device (设备信息)

#### 获取设备信息
```javascript
AndroidWebBox.device.getInfo(function(response) {
    if (response.success) {
        console.log('App版本:', response.data.appVersion);
        console.log('设备型号:', response.data.model);
        console.log('系统版本:', response.data.systemVersion);
    }
});
```

**返回数据：**
```json
{
    "appId": "com.example.app",
    "appName": "My App",
    "appVersion": "1.0.0",
    "appVersionCode": "1",
    "platform": "android",
    "system": "Android",
    "systemVersion": "13",
    "sdkVersion": 33,
    "model": "Pixel 7",
    "brand": "Google",
    "manufacturer": "Google",
    "device": "cheetah",
    "screenWidth": 1080,
    "screenHeight": 2400,
    "screenDensity": 3.0,
    "language": "zh",
    "country": "CN",
    "networkType": "unknown"
}
```

## 事件系统

### 监听原生事件

```javascript
AndroidWebBox.event.on('resume', function(data) {
    console.log('App恢复');
});

AndroidWebBox.event.on('pause', function(data) {
    console.log('App暂停');
});
```

### 发送事件到原生

```javascript
AndroidWebBox.event.emit('customEvent', {
    message: 'Hello from Web'
});
```

### 移除事件监听

```javascript
function onResume(data) {
    console.log('App恢复');
}

AndroidWebBox.event.on('resume', onResume);
// 之后移除
AndroidWebBox.event.off('resume', onResume);
```

## 错误处理

所有API回调都遵循统一格式：

```javascript
{
    success: true/false,
    data: {...},     // 成功时的数据
    error: {         // 失败时的错误信息
        code: "ERROR_CODE",
        message: "错误描述"
    },
    progress: 50     // 可选，进度值 0-100
}
```

### 常见错误码

| 错误码 | 说明 |
|-------|------|
| PERMISSION_DENIED | 权限被拒绝 |
| PLUGIN_NOT_FOUND | 插件未注册 |
| UNAVAILABLE | 功能不可用 |
| CANCELLED | 用户取消操作 |
| UNKNOWN_ACTION | 未知的插件方法 |
| INVALID_PARAMS | 参数错误 |

## 自定义插件开发

### 1. 创建插件类

```kotlin
class MyPlugin : BasePlugin() {

    override fun pluginName() = "myPlugin"

    override fun exec(action: String, params: JSONObject, callback: PluginCallback) {
        when (action) {
            "myAction" -> myAction(params, callback)
            else -> callback.error("UNKNOWN_ACTION", "Unknown action: $action")
        }
    }

    private fun myAction(params: JSONObject, callback: PluginCallback) {
        val param1 = optString(params, "param1", "default")

        // 执行你的逻辑
        callback.success(mapOf(
            "result" to "success",
            "data" to param1
        ))
    }
}
```

### 2. 注册插件

```kotlin
webContainer.getPluginManager().registerPlugin(MyPlugin())
```

### 3. 在H5中调用

```javascript
AndroidWebBox.myPlugin.myAction({
    param1: "Hello"
}, function(response) {
    if (response.success) {
        console.log(response.data.result);
    }
});
```

## 配置选项

### HybridConfig

| 配置项 | 类型 | 默认值 | 说明 |
|-------|------|--------|------|
| defaultUrl | String | file:///android_asset/index.html | 默认加载URL |
| debugMode | Boolean | false | 调试模式 |
| allowedDomains | List<String> | [] | 域名白名单 |
| enableCache | Boolean | true | 启用缓存 |
| enableDomStorage | Boolean | true | 启用DOM Storage |
| allowFileAccess | Boolean | true | 允许文件访问 |
| cacheMode | Int | LOAD_DEFAULT | 缓存模式 |

## 安全建议

1. **生产环境关闭调试模式**
2. **设置域名白名单**，只允许加载受信任的域名
3. **申请最小权限**，只申请必需的权限
4. **验证数据来源**，对传入的参数进行校验
5. **使用HTTPS**，生产环境强制HTTPS连接

## 最佳实践

### 1. 权限管理

在`AndroidManifest.xml`中只申请必需的权限：

```xml
<!-- 必需权限 -->
<uses-permission android:name="android.permission.INTERNET" />

<!-- 可选功能按需添加 -->
<uses-permission android:name="android.permission.CAMERA" />
```

### 2. 生命周期管理

```kotlin
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

override fun onDestroy() {
    webContainer.destroy()
    super.onDestroy()
}
```

### 3. 错误处理

```javascript
AndroidWebBox.camera.capture({}, function(response) {
    if (response.success) {
        // 处理成功
    } else if (response.error) {
        // 处理错误
        if (response.error.code === 'PERMISSION_DENIED') {
            // 提示用户授予权限
        }
    }
});
```

## 常见问题

### Q: 提示"AndroidWebBox未初始化"？
A: 确保在`onPageFinished`之后再调用API，或者使用`setTimeout`延迟调用。

### Q: 权限被拒绝？
A: 检查`AndroidManifest.xml`中的权限声明，并确保运行时权限已授予。

### Q: 获取的文件路径为空？
A: Android 10+使用了分区存储，建议使用URI来访问文件。

### Q: 如何调试？
A: 设置`config.debugMode = true`，使用Chrome DevTools: `chrome://inspect`

## 版本

当前版本: 1.0.0

## 许可证

MIT License
