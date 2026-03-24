# 🚀 iOSWebBox 运行指南

## 最快运行方式（推荐，3分钟）

### 步骤 1：打开 Xcode 创建项目

```bash
# 或者直接在命令行运行（Mac）
open -a Xcode
```

在 Xcode 中：
1. **File → New → Project**
2. 选择 **iOS → App**
3. 填写：
   - Product Name: `iOSWebBoxDemo`
   - Interface: **Storyboard**（稍后删除）
   - Language: **Swift**
   - 保存位置: `hybrid_framework/`（与 AndroidWebBox 同级）

### 步骤 2：添加文件到项目

在 Xcode 的项目导航器中：

1. **删除这些文件**（右键 → Delete → Move to Trash）：
   - `ViewController.swift`
   - `Main.storyboard`

2. **拖入以下文件夹**（从 `iOSWebBox/iOSWebBox/`）：
   ```
   HybridSDK/   → 拖到项目中
   Resources/   → 拖到项目中
   ```
   拖入时勾选：
   - ✅ Copy items if needed
   - ✅ Create groups
   - ✅ Add to targets（选择你的项目）

### 步骤 3：替换代码文件

在 Xcode 中：

**替换 `AppDelegate.swift`**：
```swift
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
```

**替换 `SceneDelegate.swift`**：
```swift
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        window = UIWindow(windowScene: windowScene)
        let viewController = HybridViewController()
        window?.rootViewController = viewController
        window?.makeKeyAndVisible()
    }
}
```

**创建 `HybridViewController.swift`**（新文件）：
```swift
import UIKit
import HybridSDK

class HybridViewController: UIViewController {
    var hybridWebView: HybridWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "iOSWebBox"
        view.backgroundColor = .white

        let config = HybridConfig.Builder()
            .setDebugMode(true)
            .build()

        hybridWebView = HybridWebView(frame: view.bounds)
        hybridWebView.initConfig(config: config, viewController: self)
        hybridWebView.getPluginManager()?.registerPlugins([
            CameraPlugin(),
            GalleryPlugin(),
            VideoPlugin(),
            DevicePlugin(),
            NetworkPlugin()
        ])

        view.addSubview(hybridWebView)

        // 加载本地 HTML
        if let htmlPath = Bundle.main.path(forResource: "index", ofType: "html", inDirectory: "html") {
            hybridWebView.loadFileURL(URL(fileURLWithPath: htmlPath), allowingReadAccessTo: URL(fileURLWithPath: htmlPath.deletingLastPathComponent().path))
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        hybridWebView.frame = view.bounds
    }

    deinit {
        hybridWebView?.cleanup()
    }
}
```

### 步骤 4：添加 Alamofire 依赖

1. 选择项目文件（蓝色图标）
2. **Package Dependencies** 标签
3. 点击 **+** 按钮
4. 搜索或输入：`https://github.com/Alamofire/Alamofire.git`
5. 选择版本规则：**Up to Next Major Version: 5.8.0**
6. 点击 **Add Package**
7. 在弹出的窗口中，确保选中你的项目 Target，点击 **Add Package**

### 步骤 5：配置 Info.plist

在项目的 `Info.plist` 文件最后添加（右键 → Open As → Source Code）：

```xml
<key>NSCameraUsageDescription</key>
<string>需要相机权限拍照</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>需要访问相册选择照片</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>需要保存照片到相册</string>
<key>NSMicrophoneUsageDescription</key>
<string>需要麦克风权限录制视频</string>
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoadsInWebContent</key>
    <true/>
</dict>
```

### 步骤 6：配置项目设置

1. 选择项目 → **Target → General**
2. 设置：
   - **Deployment Info → Minimum Deployments**: `14.0`
   - **Main Interface**: 删除 "Main" 文字，留空

3. 选择 **Build Settings**
4. 搜索 **Other Linker Flags**
5. 双击 **Other**，添加值：`-ObjC`

### 步骤 7：运行！

1. 选择一个模拟器（如 **iPhone 15**）
2. 点击 **▶ Run** 按钮
3. 首次运行会自动安装 Alamofire 依赖
4. 等待编译完成，应用会自动启动

## 预期结果

应用启动后，你会看到一个紫色渐变的 Demo 页面，包含：

- 📱 **设备信息** - 点击查看 iOS 设备信息
- 📷 **拍照** - 在真机上可以拍照
- 🖼️ **相册** - 选择照片或视频
- 🌐 **网络请求** - 测试 GET/POST 请求

点击按钮会在页面下方显示结果。

## 常见问题

### ❌ "Cannot find module 'HybridSDK'"
**解决**：
- 确保 HybridSDK 文件夹已添加到项目
- 检查 Target Membership 是否勾选

### ❌ "Cannot find 'Alamofire' in scope"
**解决**：
- 检查 Alamofire 是否通过 SPM 添加成功
- Product → Clean Build Folder (⇧⌘K)
- 重新编译

### ❌ "Thread 1: Fatal error: No such module 'HybridSDK'"
**解决**：
- 确保 HybridSDK 文件夹显示为蓝色（不是黄色）
- 蓝色 = folder reference（正确）
- 黄色 = group（可能有问题）

### ❌ WebView 显示空白
**解决**：
- 确保 index.html 已添加到 Bundle
- 检查 Target Membership 是否勾选
- 查看 Xcode Console 输出

### ❌ 相机/相册不工作
**解决**：
- 在真机上测试（模拟器不支持相机）
- 检查 Info.plist 权限描述
- 确保设备授权了相机/相册权限

## 调试技巧

### 查看 Console 输出
```
⌘ + ⇧ + Y
```

### 检查 WebView
1. Safari → Develop → [你的模拟器]
2. 选择你的 WebView
3. 查看控制台输出

### 清理项目
```
Product → Clean Build Folder (⇧⌘K)
```

## 下一步

运行成功后：

1. **测试所有功能** - 在真机上完整测试
2. **修改 HTML** - 编辑 `index.html` 定制界面
3. **集成到项目** - 将 HybridSDK 复制到你的实际项目
4. **开发插件** - 参考 BasePlugin.swift 开发自定义插件

## 与 AndroidWebBox 对比

| 功能 | AndroidWebBox | iOSWebBox |
|------|---------------|-----------|
| JavaScript API | ✅ 完全相同 | ✅ 完全相同 |
| 设备信息 | ✅ | ✅ |
| 相机拍照 | ✅ | ✅ |
| 相册选择 | ✅ | ✅ |
| 视频录制 | ✅ | ✅ |
| 网络请求 | ✅ OkHttp | ✅ Alamofire |
| H5 兼容性 | ✅ | ✅ 100% |

同一套 HTML 代码可以在两个平台上运行，无需修改！

## 获取帮助

- 查看 `MANUAL_SETUP.md` 获取详细说明
- 查看 `README.md` 了解 API 文档
- 检查 Xcode 的错误输出

祝开发顺利！🎉
