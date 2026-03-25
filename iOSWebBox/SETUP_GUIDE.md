# iOSWebBox Xcode 设置指南

## 📋 项目结构

```
iOSWebBox/
├── iOSWebBox/                    # Xcode 项目
│   ├── iOSWebBox/                # App 源码
│   │   ├── AppDelegate.swift
│   │   ├── SceneDelegate.swift
│   │   ├── HybridViewController.swift
│   │   ├── Assets.xcassets
│   │   └── Info.plist
│   ├── iOSWebBoxTests/
│   └── iOSWebBoxUITests/
├── hybrid-sdk/                   # SDK 源码 (需要添加到项目)
│   ├── Core/
│   │   ├── HybridConfig.swift
│   │   ├── HybridWebView.swift
│   │   ├── JSBridge.swift
│   │   ├── PluginManager.swift
│   │   ├── PluginContext.swift
│   │   └── PluginCallback.swift
│   ├── Plugin/
│   │   ├── HybridPlugin.swift
│   │   └── BasePlugin.swift
│   └── Plugins/
│       ├── DevicePlugin.swift
│       ├── CameraPlugin.swift
│       ├── GalleryPlugin.swift
│       ├── VideoPlugin.swift
│       └── NetworkPlugin.swift
└── resources/                    # 资源文件 (需要添加到项目)
    ├── js/
    │   └── hybrid-sdk.js
    └── html/
        └── index.html
```

## 🔧 Xcode 配置步骤

### 步骤 1: 打开项目

```bash
cd iOSWebBox
open iOSWebBox.xcodeproj
```

### 步骤 2: 添加 hybrid-sdk 文件夹

1. 在 Xcode 项目导航器中，右键点击 "iOSWebBox" 文件夹
2. 选择 "Add Files to iOSWebBox..."
3. 导航到 `hybrid-sdk` 文件夹
4. **重要**: 选择 "Create folder references" (蓝色文件夹图标)
5. 确保 "Add to targets" 中勾选了 "iOSWebBox"
6. 点击 "Add"

**验证**: `hybrid-sdk` 应该在项目导航器中显示为**蓝色**文件夹

### 步骤 3: 添加 resources 文件夹

1. 在 Xcode 项目导航器中，右键点击 "iOSWebBox" 文件夹
2. 选择 "Add Files to iOSWebBox..."
3. 导航到 `resources` 文件夹
4. **重要**: 选择 "Create folder references" (蓝色文件夹图标)
5. 确保 "Add to targets" 中勾选了 "iOSWebBox"
6. 点击 "Add"

**验证**: `resources` 应该在项目导航器中显示为**蓝色**文件夹

### 步骤 4: 配置 iOS 部署目标

1. 选择项目 "iOSWebBox" (蓝色图标)
2. 选择 "iOSWebBox" target
3. 在 "General" 标签页中
4. 设置 "Minimum Deployments" -> "iOS" 为 **14.0** (PHPickerViewController 要求)

### 步骤 5: 添加框架依赖

1. 选择项目 "iOSWebBox"
2. 选择 "iOSWebBox" target
3. 在 "General" 标签页中
4. 找到 "Frameworks, Libraries, and Embedded Content"
5. 点击 "+" 按钮
6. 添加以下系统框架:
   - `WebKit.framework`
   - `AVFoundation.framework`
   - `PhotosUI.framework`
   - `CoreServices.framework`

### 步骤 6: 配置 Bundle Resources

1. 选择 "Build Phases" 标签页
2. 展开 "Copy Bundle Resources"
3. 确保看到:
   - `resources/js/hybrid-sdk.js`
   - `resources/html/index.html`

## ▶️ 运行项目

### 选择模拟器

1. 点击 scheme 选择器 (顶部工具栏)
2. 选择一个 iPhone 模拟器 (iPhone 15 或更新推荐)

### 构建并运行

1. 按 `⌘ + R` 或点击左上角的运行按钮
2. 等待构建完成
3. 应用启动后应该看到紫色渐变背景的演示页面

## ✅ 成功标准

如果一切正常，你应该看到:
- 📱 iOSWebBox Demo 标题
- 🖥️ 设备信息卡片
- 📷 相机卡片
- 🖼️ 相册卡片
- 🎬 视频卡片
- 🌐 网络请求卡片

点击 "获取设备信息" 按钮，应该看到设备信息显示。

## 🐛 故障排除

### 错误: "Cannot find type 'HybridViewController' in scope"

**原因**: hybrid-sdk 文件夹未正确添加到项目

**解决**:
1. 从项目中移除 hybrid-sdk 文件夹 (只删除引用,不删除文件)
2. 重新添加,确保选择 "Create folder references" (蓝色文件夹)

### 错误: "Failed to load hybrid-sdk.js"

**原因**: resources 文件夹未正确添加到项目

**解决**:
1. 从项目中移除 resources 文件夹
2. 重新添加,确保选择 "Create folder references" (蓝色文件夹)
3. 检查 "Copy Bundle Resources" 中包含 js 文件

### 空白页面

**原因**: HTML 文件路径错误

**解决**:
1. 检查 resources 文件夹是蓝色(文件夹引用)而非黄色(group)
2. 清理项目 (Product > Clean Build Folder, `⌘ + Shift + K`)
3. 重新构建

### 相机功能在模拟器上无法使用

**说明**: 模拟器不支持相机功能,这是正常的。请使用真机测试:
1. 连接 iPhone 设备
2. 选择设备作为运行目标
3. 信任开发者证书(首次运行时)

## 📱 API 对比

iOSWebBox 与 AndroidWebBox 保持 100% JavaScript API 兼容:

| 功能 | Android 实现 | iOS 实现 |
|------|------------|---------|
| 设备信息 | DeviceInfoPlugin | DevicePlugin |
| 相机 | CameraPlugin | CameraPlugin |
| 相册 | GalleryPlugin | GalleryPlugin |
| 视频 | VideoPlugin | VideoPlugin |
| 网络 | OkHttp | URLSession |

JavaScript 调用方式完全相同:

```javascript
// 设备信息
AndroidWebBox.device.getInfo(callback);

// 相机
AndroidWebBox.camera.capture(options, callback);

// 相册
AndroidWebBox.gallery.pick(options, callback);

// 视频
AndroidWebBox.video.record(options, callback);

// 网络
AndroidWebBox.http.get(options, callback);
AndroidWebBox.http.post(options, callback);
```

## 📄 License

MIT
