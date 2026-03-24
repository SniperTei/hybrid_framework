# iOSWebBox

iOS 版本的 AndroidWebBox 混合开发框架，提供与 Android 版本完全兼容的 API，让同一套 H5 代码无需修改即可在 iOS 和 Android 双平台运行。

## 特性

- 🚀 **API 完全兼容** - 与 Android 版本保持一致的 API 设计
- 📱 **原生能力** - 充分利用 iOS 原生能力 (WKWebView, PHPickerViewController, UIImagePickerController 等)
- 🔌 **插件化架构** - 灵活的插件系统，易于扩展
- 🌐 **网络请求** - 基于 Alamofire 的强大网络请求能力
- 📷 **多媒体支持** - 相机、相册、视频录制完整支持
- 🔒 **安全机制** - URL 白名单、权限管理、数据隔离
- 📦 **Swift Package Manager** - 现代化的依赖管理

## 系统要求

- iOS 14.0+
- Xcode 14.0+
- Swift 5.9+

## 快速开始

### 安装

使用 Swift Package Manager 安装:

```swift
dependencies: [
    .package(url: "https://github.com/your-repo/iOSWebBox.git", from: "1.0.0")
]
```

### 基本使用

```swift
import UIKit
import HybridSDK

class ViewController: UIViewController {

    private var hybridWebView: HybridWebView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // 1. 创建配置
        let config = HybridConfig.Builder()
            .setDefaultURL("https://your-domain.com/index.html")
            .setDebugMode(true)
            .build()

        // 2. 初始化 WebView
        hybridWebView = HybridWebView(frame: view.bounds)
        hybridWebView.initConfig(config: config, viewController: self)

        // 3. 注册插件
        hybridWebView.getPluginManager()?.registerPlugins([
            CameraPlugin(),
            GalleryPlugin(),
            VideoPlugin(),
            DevicePlugin(),
            NetworkPlugin()
        ])

        // 4. 添加到视图并加载
        view.addSubview(hybridWebView)
        hybridWebView.loadHybridURL(config.defaultURL)
    }

    deinit {
        hybridWebView?.cleanup()
    }
}
```

## 配置

### HybridConfig

```swift
let config = HybridConfig.Builder()
    .setDefaultURL("https://example.com")
    .setDebugMode(true)
    .setAllowedDomains(["example.com", "api.example.com"])
    .setEnableCache(true)
    .setEnableDomStorage(true)
    .setAllowFileAccess(true)
    .setUserAgent("MyApp/1.0")
    .build()
```

### NetworkConfig

```swift
let networkConfig = NetworkConfig.Builder()
    .setBaseURL("https://api.example.com")
    .setConnectTimeout(30.0)
    .setReadTimeout(30.0)
    .addDefaultHeader("Authorization", value: "Bearer token")
    .build()
```

## JavaScript API

### 设备信息

```javascript
AndroidWebBox.device.getInfo(function(result) {
    if (result.success) {
        console.log(result.data);
        // {
        //   appId: "com.example.app",
        //   appName: "My App",
        //   platform: "ios",
        //   systemVersion: "17.0",
        //   ...
        // }
    }
});
```

### 相机

```javascript
AndroidWebBox.camera.capture({
    quality: 80
}, function(result) {
    if (result.success) {
        console.log("照片路径: " + result.data.path);
    }
});
```

### 相册

```javascript
AndroidWebBox.gallery.pick({
    maxCount: 3,
    type: "image" // 或 "video", "all"
}, function(result) {
    if (result.success) {
        console.log("选择了 " + result.data.count + " 个文件");
        result.data.items.forEach(item => {
            console.log(item.path);
        });
    }
});
```

### 视频

```javascript
AndroidWebBox.video.record({
    maxDuration: 60 // 秒
}, function(result) {
    if (result.success) {
        console.log("视频路径: " + result.data.path);
        console.log("时长: " + result.data.duration + " 秒");
    }
});
```

### 网络请求

```javascript
// GET 请求
AndroidWebBox.http.get({
    url: "/api/user",
    headers: {
        "Authorization": "Bearer token"
    }
}, function(result) {
    if (result.success) {
        console.log(result.data);
    }
});

// POST 请求
AndroidWebBox.http.post({
    url: "/api/user",
    name: "John",
    age: 30
}, function(result) {
    if (result.success) {
        console.log(result.data);
    }
});

// 文件上传
AndroidWebBox.http.upload({
    url: "/api/upload",
    filePath: "/path/to/file.jpg"
}, function(result) {
    if (result.success) {
        console.log("上传成功");
    }
});

// 文件下载
AndroidWebBox.http.download({
    url: "/api/file/123",
    savePath: "/path/to/save/file.jpg"
}, function(result) {
    if (result.progress !== undefined) {
        console.log("下载进度: " + result.progress + "%");
    } else if (result.success) {
        console.log("下载完成: " + result.data.path);
    }
});
```

### 事件系统

```javascript
// 监听事件
AndroidWebBox.event.on("customEvent", function(data) {
    console.log("收到事件: " + data);
});

// 发送事件到 Native
AndroidWebBox.event.emit("customEvent", { message: "Hello from H5" });

// 移除监听
AndroidWebBox.event.off("customEvent", callback);
```

## 内置插件

### DevicePlugin

获取设备和应用信息。

**方法**: `getInfo(callback)`

**返回数据**:
- `appId`: 应用包名
- `appName`: 应用名称
- `appVersion`: 应用版本
- `platform`: 平台 (ios)
- `system`: 系统名称
- `systemVersion`: 系统版本
- `model`: 设备型号
- `screenWidth`: 屏幕宽度
- `screenHeight`: 屏幕高度
- `screenDensity`: 屏幕密度
- `batteryLevel`: 电池电量
- `batteryState`: 电池状态

### CameraPlugin

调用相机拍照。

**方法**: `capture(options, callback)`

**参数**:
- `quality`: 图片质量 (1-100)

**返回数据**:
- `path`: 照片路径
- `width`: 图片宽度
- `height`: 图片高度

### GalleryPlugin

从相册选择照片或视频。

**方法**: `pick(options, callback)`

**参数**:
- `maxCount`: 最大选择数量
- `type`: 媒体类型 ("image", "video", "all")

**返回数据**:
- `items`: 文件数组
- `count`: 文件数量

### VideoPlugin

录制视频。

**方法**: `record(options, callback)`

**参数**:
- `maxDuration`: 最大时长 (秒)

**返回数据**:
- `path`: 视频路径
- `duration`: 视频时长
- `size`: 文件大小

### NetworkPlugin

HTTP 网络请求。

**方法**: `get/post/put/delete/patch/upload/download/setConfig`

**参数**:
- `url`: 请求地址
- `headers`: 请求头
- `timeout`: 超时时间
- `filePath`: 文件路径 (上传/下载)

## 权限配置

在 `Info.plist` 中添加以下权限描述:

```xml
<!-- 相机权限 -->
<key>NSCameraUsageDescription</key>
<string>需要相机权限拍照</string>

<!-- 相册权限 -->
<key>NSPhotoLibraryUsageDescription</key>
<string>需要访问相册选择照片</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>需要保存照片到相册</string>

<!-- 麦克风权限 -->
<key>NSMicrophoneUsageDescription</key>
<string>需要麦克风权限录制视频</string>
```

## 自定义插件

### 创建插件

```swift
class CustomPlugin: BasePlugin {

    override func pluginName() -> String {
        return "custom"
    }

    override func exec(action: String, params: [String: Any], callback: PluginCallback) {
        switch action {
        case "doSomething":
            doSomething(params: params, callback: callback)
        default:
            callback.error(code: "UNKNOWN_ACTION", message: "Unknown action")
        }
    }

    private func doSomething(params: [String: Any], callback: PluginCallback) {
        // 处理逻辑
        let result = [
            "message": "Hello from Custom Plugin!"
        ]
        callback.success(result)
    }
}
```

### 注册插件

```swift
hybridWebView.getPluginManager()?.registerPlugin(CustomPlugin())
```

### JavaScript 调用

```javascript
AndroidWebBox.callNative('custom', 'doSomething', {
    param1: 'value1'
}, function(result) {
    if (result.success) {
        console.log(result.data);
    }
});
```

## 项目结构

```
iOSWebBox/
├── Package.swift                          # SPM 配置
├── iOSWebBox/
│   ├── App/                              # 应用入口
│   │   ├── AppDelegate.swift
│   │   ├── SceneDelegate.swift
│   │   └── Info.plist
│   ├── ViewController/                    # 视图控制器
│   │   └── HybridViewController.swift
│   ├── HybridSDK/                        # 混合框架核心
│   │   ├── Core/                         # 核心类
│   │   │   ├── HybridWebView.swift
│   │   │   ├── JSBridge.swift
│   │   │   ├── PluginManager.swift
│   │   │   └── HybridConfig.swift
│   │   ├── Plugin/                       # 插件系统
│   │   │   ├── HybridPlugin.swift
│   │   │   ├── BasePlugin.swift
│   │   │   ├── PluginCallback.swift
│   │   │   └── PluginContext.swift
│   │   ├── Plugins/                      # 内置插件
│   │   │   ├── CameraPlugin.swift
│   │   │   ├── GalleryPlugin.swift
│   │   │   ├── VideoPlugin.swift
│   │   │   ├── DevicePlugin.swift
│   │   │   └── NetworkPlugin.swift
│   │   └── Network/                      # 网络配置
│   │       └── NetworkConfig.swift
│   └── Resources/                        # 资源文件
│       ├── js/
│       │   └── hybrid-sdk.js            # JavaScript SDK
│       └── html/
│           └── index.html               # 示例页面
```

## 与 Android 版本的兼容性

iOSWebBox 在以下方面与 AndroidWebBox 保持完全兼容:

1. **JavaScript API** - 完全相同的方法签名和调用方式
2. **插件接口** - 相同的插件生命周期和方法定义
3. **数据格式** - 统一的请求和响应数据格式
4. **错误处理** - 一致的错误码和错误消息格式
5. **事件系统** - 相同的事件监听和发送机制

## 架构设计

```
┌─────────────────────────────────────────────────────────┐
│                    H5 Application                        │
└─────────────────────────────────────────────────────────┘
                            ↓
                    AndroidWebBox.js
                            ↓
┌─────────────────────────────────────────────────────────┐
│                      JSBridge                            │
│  - WKScriptMessageHandler                                │
│  - JavaScript 注入                                        │
│  - 事件管理                                               │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                   PluginManager                          │
│  - 插件注册                                               │
│  - 请求路由                                               │
│  - 生命周期管理                                           │
└─────────────────────────────────────────────────────────┘
                            ↓
┌───────────────────┬───────────────────┬─────────────────┐
│   CameraPlugin    │  GalleryPlugin    │  DevicePlugin   │
├───────────────────┼───────────────────┼─────────────────┤
│   VideoPlugin     │  NetworkPlugin    │  CustomPlugin   │
└───────────────────┴───────────────────┴─────────────────┘
```

## 许可证

MIT License

## 作者

AndroidWebBox Team

## 相关链接

- [AndroidWebBox](../AndroidWebBox) - Android 版本
- [示例代码](./iOSWebBox/Resources/html/index.html) - 完整示例
- [API 文档](./API.md) - 详细 API 文档
