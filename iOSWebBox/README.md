# iOSWebBox

iOS 混合开发框架,与 AndroidWebBox API 完全兼容。

## ✨ 特性

- 🚀 **100% JavaScript API 兼容**: 同一套 H5 代码可在 Android 和 iOS 运行
- 📱 **原生功能访问**: 相机、相册、视频、设备信息、网络请求
- 🔌 **插件化架构**: 可扩展的插件系统
- 🎨 **现代 Swift 实现**: Swift 5.9+, iOS 14+
- 🌐 **WKWebView**: 基于 Apple 官方 WebView 实现

## 📦 内置插件

| 插件 | 功能 | iOS 实现 |
|------|------|---------|
| DevicePlugin | 设备信息 | UIDevice, UIScreen |
| CameraPlugin | 拍照 | UIImagePickerController |
| GalleryPlugin | 相册选择 | PHPickerViewController (iOS 14+) |
| VideoPlugin | 视频录制 | UIImagePickerController |
| NetworkPlugin | 网络请求 | URLSession |

## 🚀 快速开始

### 1. 打开项目

```bash
cd iOSWebBox
open iOSWebBox.xcodeproj
```

### 2. 配置 Xcode

详见 [SETUP_GUIDE.md](SETUP_GUIDE.md)

关键步骤:
- 将 `hybrid-sdk/` 和 `resources/` 添加到 Xcode 项目 (蓝色文件夹引用)
- 设置 iOS 部署目标为 14.0
- 添加所需系统框架

### 3. 运行

按 `⌘ + R` 或点击运行按钮

## 📖 API 使用

### JavaScript 调用

```javascript
// 设备信息
AndroidWebBox.device.getInfo(function(response) {
    if (response.success) {
        console.log('设备:', response.data);
    }
});

// 拍照
AndroidWebBox.camera.capture({}, function(response) {
    if (response.success) {
        console.log('照片路径:', response.data.path);
    }
});

// 选择照片
AndroidWebBox.gallery.pick({ limit: 3 }, function(response) {
    if (response.success) {
        console.log('选中的照片:', response.data.images);
    }
});

// 录制视频
AndroidWebBox.video.record({ maxDuration: 30 }, function(response) {
    if (response.success) {
        console.log('视频路径:', response.data.path);
    }
});

// 网络请求
AndroidWebBox.http.get({
    url: 'https://api.example.com/data',
    headers: { 'Authorization': 'Bearer token' }
}, function(response) {
    if (response.success) {
        console.log('响应数据:', response.data);
    }
});
```

## 🏗️ 项目结构

```
iOSWebBox/
├── iOSWebBox/                    # App 源码
│   ├── iOSWebBox/
│   │   ├── AppDelegate.swift
│   │   ├── SceneDelegate.swift
│   │   ├── HybridViewController.swift
│   │   ├── Assets.xcassets/
│   │   └── Info.plist
│   ├── iOSWebBoxTests/
│   ├── iOSWebBoxUITests/
│   └── iOSWebBox.xcodeproj/
├── hybrid-sdk/                   # SDK 源码
│   ├── Core/
│   │   ├── HybridConfig.swift        # 配置类
│   │   ├── HybridWebView.swift       # WebView 容器
│   │   ├── JSBridge.swift            # JS-Native 通信桥
│   │   ├── PluginManager.swift       # 插件管理器
│   │   ├── PluginContext.swift       # 插件上下文
│   │   └── PluginCallback.swift      # 插件回调
│   ├── Plugin/
│   │   ├── HybridPlugin.swift        # 插件协议
│   │   └── BasePlugin.swift          # 插件基类
│   └── Plugins/
│       ├── DevicePlugin.swift        # 设备信息插件
│       ├── CameraPlugin.swift        # 相机插件
│       ├── GalleryPlugin.swift       # 相册插件
│       ├── VideoPlugin.swift         # 视频插件
│       └── NetworkPlugin.swift       # 网络插件
├── resources/                    # 资源文件
│   ├── js/
│   │   └── hybrid-sdk.js            # JavaScript SDK
│   └── html/
│       └── index.html               # 演示页面
├── README.md
└── SETUP_GUIDE.md
```

## 🔧 开发

### 添加自定义插件

1. 创建插件类继承 `BasePlugin`:

```swift
public class MyPlugin: BasePlugin {
    public override func pluginName() -> String {
        return "myplugin"
    }

    public override func exec(action: String, params: [String: Any], callback: PluginCallback) {
        switch action {
        case "myAction":
            // 处理逻辑
            callback.success(["result": "hello"])
        default:
            super.exec(action: action, params: params, callback: callback)
        }
    }
}
```

2. 注册插件:

```swift
hybridWebView.getPluginManager()?.registerPlugins([
    MyPlugin()
])
```

3. JavaScript 调用:

```javascript
AndroidWebBox.callNative('myplugin', 'myAction', { param: 'value' }, callback);
```

## 📱 与 AndroidWebBox 对比

| 特性 | AndroidWebBox | iOSWebBox |
|------|--------------|-----------|
| WebView | WebView | WKWebView |
| JS Bridge | JavascriptInterface | WKScriptMessageHandler |
| 网络 | OkHttp | URLSession |
| 相册 | Intent (ACTION_PICK) | PHPickerViewController |
| 最低版本 | Android 5.0+ | iOS 14.0+ |
| JavaScript API | ✅ 相同 | ✅ 相同 |

## 🛠️ 技术栈

- **语言**: Swift 5.9+
- **UI 框架**: UIKit
- **WebView**: WKWebView
- **最低支持**: iOS 14.0+
- **架构模式**: 插件化架构

## 📄 License

MIT

## 🤝 贡献

欢迎提交 Issue 和 Pull Request!

## 📞 联系

如有问题,请提交 Issue。
