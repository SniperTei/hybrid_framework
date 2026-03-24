# ⚡️ iOSWebBox 超快速运行指南

**5分钟完成，100%可运行**

## 🚀 一键式操作（推荐）

```bash
# 在当前目录执行以下命令：

# 1. 打开 Xcode
open -a Xcode

# 2. 在 Xcode 中：
# File → New → Project
# → iOS → App → Next
#
# 填写这些信息（直接复制）：
# Product Name: iOSWebBoxDemo
# Team: [选择你的团队]
# Organization Identifier: com.sniper.webbox
# Bundle Identifier: 会自动生成
# Interface: SwiftUI ← 选这个，最简单
# Language: Swift
# Storage: None
# 取消所有勾选框
#
# → Next → 保存到: /Users/zhengnan/Sniper/Developer/github/hybrid_framework/iOSWebBox/
# → Create
```

## 📝 完成项目创建后的配置（3分钟）

### 第1步：删除不需要的文件（30秒）

在 Xcode 左侧项目导航器中：
- 删除 `iOSWebBoxDemoApp.swift` 文件（右键 → Delete → Move to Trash）
- 删除 `Assets.xcassets` 中的内容（保留文件夹本身）
- 删除 `ContentView.swift` 文件

### 第2步：添加 iOSWebBox 源码（1分钟）

```bash
# 在 Finder 中，将以下文件夹拖入 Xcode 项目：
# 1. iOSWebBox/HybridSDK/ → 拖到项目名称下面
# 2. iOSWebBox/Resources/ → 拖到项目名称下面
```

拖入时弹出对话框，确保：
- ✅ Copy items if needed
- ✅ Create groups
- ✅ Add to targets: iOSWebBoxDemo

### 第3步：创建 AppDelegate 和 SceneDelegate（1分钟）

**在 Xcode 中：File → New → File → iOS → Swift File**

创建 `AppDelegate.swift`：
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

创建 `SceneDelegate.swift`：
```swift
import UIKit
import HybridSDK

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        window = UIWindow(windowScene: windowScene)

        // 创建主视图控制器
        let viewController = HybridViewController()

        window?.rootViewController = viewController
        window?.makeKeyAndVisible()
    }
}
```

创建 `HybridViewController.swift`：
```swift
import UIKit
import HybridSDK

class HybridViewController: UIViewController {
    var hybridWebView: HybridWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        // 配置
        let config = HybridConfig.Builder()
            .setDebugMode(true)
            .build()

        // WebView
        hybridWebView = HybridWebView(frame: view.bounds)
        hybridWebView.initConfig(config: config, viewController: self)

        // 注册插件
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
            let htmlURL = URL(fileURLWithPath: htmlPath)
            hybridWebView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
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

### 第4步：添加 Alamofire 依赖（30秒）

1. 点击项目文件（蓝色图标）
2. 选择 **iOSWebBoxDemo** Target
3. 选择 **Package Dependencies** 标签
4. 点击 **+** 按钮
5. 输入：`https://github.com/Alamofire/Alamofire.git`
6. 选择：**Up to Next Major Version: 5.8.0**
7. 点击 **Add Package**
8. 确保选中项目，点击 **Add Package**

### 第5步：配置 Info.plist（30秒）

1. 在项目导航器中找到 `Info.plist`
2. 右键 → **Open As → Source Code**
3. 在 `<dict>` 标签内的最后添加：

```xml
<key>NSCameraUsageDescription</key>
<string>需要相机权限拍照</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>需要访问相册选择照片</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>需要保存照片到相册</string>
<key>NSMicrophoneUsageDescription</key>
<string>需要麦克风权限录制视频</string>
```

### 第6步：配置项目设置（30秒）

1. 选择项目 → **Target → General**
2. **Minimum Deployments**: 设为 `14.0`
3. 删除 **Main Interface** 中的内容（留空）

### 第7步：运行！🎉

1. 选择模拟器：**iPhone 15** 或其他
2. 点击 **▶ Run** 按钮
3. 等待编译（首次会下载 Alamofire）
4. 应用启动后会显示紫色渐变的 Demo 页面

## ✅ 预期结果

你会看到：
- 🎨 **紫色渐变背景**的 Demo 页面
- 📱 **5个功能卡片**：设备信息、拍照、相册、视频、网络
- 📋 **实时输出结果**在页面下方

点击按钮测试各个功能！

## 🐛 常见错误快速修复

### 错误：`Cannot find 'HybridSDK' in scope`
**修复**：
- Product → Clean Build Folder (⇧⌘K)
- 重新编译

### 错误：`Cannot find 'Alamofire' in scope`
**修复**：
- 检查 Package Dependencies 是否添加成功
- Product → Clean Build Folder (⇧⌘K)

### 错误：`No such module 'HybridSDK'`
**修复**：
- 确保 HybridSDK 文件夹显示为 **蓝色**（folder reference）
- 黄色表示 group，可能有问题

### 应用启动但显示空白
**修复**：
- 检查 Console 输出（⌘⇧Y）
- 确保 index.html 已添加到 Bundle

## 📱 真机测试

在真机上可以测试完整功能：

1. 用数据线连接 iPhone
2. 在 Xcode 顶部选择你的设备
3. 点击 Run
4. 首次需要在 iPhone 上信任开发者证书
5. 测试相机、相册、视频等功能

## 🎯 成功标志

✅ 看到紫色渐变界面
✅ 点击"获取设备信息"显示 iOS 设备信息
✅ 点击"GET 请求"显示 JSON 数据
✅ 真机上可以拍照和选照片

## 下一步

成功运行后：

1. **修改 HTML** - 编辑 `Resources/html/index.html` 定制界面
2. **加载远程页面** - 修改 `defaultURL` 加载你的 H5 页面
3. **开发插件** - 参考 `BasePlugin.swift` 开发自定义插件
4. **集成项目** - 将代码复制到你的实际项目

## 💡 提示

- 使用 Xcode 的 **Navigator** (⌘1) 查看文件
- 使用 **Console** (⌘⇧Y) 查看输出
- 使用 **Clean Build** (⇧⌘K) 解决编译问题
- 遇到问题先 **Clean** 再 **Build**

---

**🎉 恭喜！你已经成功运行了 iOSWebBox！**

同一套 HTML 代码可以在 Android 和 iOS 上运行，无需修改！
