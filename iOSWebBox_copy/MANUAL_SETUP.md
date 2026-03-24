# iOSWebBox Xcode 项目设置指南

本指南将帮助你在 Xcode 中创建一个可运行的 iOSWebBox 项目。

## 方法 1：手动创建 Xcode 项目（推荐）

### 步骤 1：创建新的 Xcode 项目

1. 打开 Xcode
2. 选择 **File → New → Project**
3. 选择 **iOS → App**
4. 填写项目信息：
   - **Product Name**: `iOSWebBoxDemo`
   - **Team**: 选择你的开发团队
   - **Organization Identifier**: `com.sniper.webbox`
   - **Bundle Identifier**: `com.sniper.webbox.iosdemo`
   - **Interface**: **Storyboard** (我们会删除它)
   - **Language**: **Swift**
   - **Storage**: None
   - 取消勾选 "Use Core Data"
5. 选择保存位置：`hybrid_framework/iOSWebBox/`
6. 点击 **Create**

### 步骤 2：添加项目文件

1. 在 Xcode 项目导航器中，删除以下文件（Move to Trash）：
   - `ViewController.swift`
   - `Main.storyboard`
   - `Assets.xcassets` 中的 AppIcon 以外的内容（或者保留）

2. 从 `iOSWebBox/iOSWebBox/` 目录拖拽以下文件夹到 Xcode 项目中：
   - `HybridSDK/` （选择 "Create groups"，勾选 "Copy items if needed"）
   - `Resources/`

3. 在项目设置中：
   - 选择项目 → Target → **General**
   - 在 **Frameworks, Libraries, and Embedded Content** 中，点击 **+** 添加：
     - `Alamofire` (通过 Swift Package Manager)
     - 或者在 **Package Dependencies** 中添加 Alamofire

### 步骤 3：添加 Swift Package Manager 依赖

1. 选择项目文件（蓝色图标）
2. 选择 **Package Dependencies** 标签
3. 点击 **+** 按钮
4. 输入 Alamofire 的 URL：`https://github.com/Alamofire/Alamofire.git`
5. 选择版本：`Up to Next Major: 5.8.0`
6. 点击 **Add Package**

### 步骤 4：配置 Info.plist

在项目的 `Info.plist` 文件中添加以下权限：

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
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSAllowsArbitraryLoadsInWebContent</key>
    <true/>
</dict>
```

### 步骤 5：修改 AppDelegate

替换 `AppDelegate.swift` 为以下内容：

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

### 步骤 6：修改 SceneDelegate

替换 `SceneDelegate.swift` 为以下内容：

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

        // 创建主视图控制器
        let viewController = HybridViewController()

        window?.rootViewController = viewController
        window?.makeKeyAndVisible()
    }
}
```

### 步骤 7：添加 HybridViewController

创建新文件 `HybridViewController.swift`：

```swift
import UIKit
import HybridSDK

class HybridViewController: UIViewController {

    private var hybridWebView: HybridWebView!

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "iOSWebBox Demo"
        view.backgroundColor = .white

        setupWebView()
    }

    private func setupWebView() {
        // 创建配置
        let config = HybridConfig.Builder()
            .setDefaultURL("about:blank")  // 默认空白页，下面会加载本地HTML
            .setDebugMode(true)
            .build()

        // 初始化 WebView
        hybridWebView = HybridWebView(frame: view.bounds)
        hybridWebView.initConfig(config: config, viewController: self)

        // 注册所有插件
        hybridWebView.getPluginManager()?.registerPlugins([
            CameraPlugin(),
            GalleryPlugin(),
            VideoPlugin(),
            DevicePlugin(),
            NetworkPlugin()
        ])

        // 添加到视图
        hybridWebView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hybridWebView)

        // 加载本地示例 HTML
        loadLocalHTML()

        // 设置错误监听
        hybridWebView.setErrorListener { [weak self] error, url in
            print("WebView error: \(error.localizedDescription)")

            // 显示错误提示
            let alert = UIAlertController(
                title: "Error",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(alert, animated: true)
        }
    }

    private func loadLocalHTML() {
        // 从 Bundle 加载 HTML
        guard let htmlPath = Bundle.main.path(forResource: "index", ofType: "html", inDirectory: "html") else {
            print("HTML file not found")
            return
        }

        let htmlURL = URL(fileURLWithPath: htmlPath)
        hybridWebView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
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

### 步骤 8：添加资源文件

1. 在 Xcode 项目中，创建一个文件夹叫 `Resources`（如果还没有）
2. 将 `iOSWebBox/Resources/` 中的文件添加到 Bundle：
   - 右键项目 → **Add Files to "ProjectName"**
   - 选择 `index.html` 和 `hybrid-sdk.js`
   - 勾选 **Copy items if needed**
   - 确保勾选 **Target Membership** 中的项目 Target

3. 确保 `index.html` 中的 JS 路径正确：
   ```html
   <script src="./hybrid-sdk.js"></script>
   ```

### 步骤 9：配置项目设置

1. 选择项目 → **Target → General**
2. 设置：
   - **Deployment Info → iPhone Deployment Target**: `14.0`
   - **Main Interface**: 清空（删除 "Main"）
   - **Supported Destinations**: iPhone

3. 选择 **Build Settings**
   - 搜索 **Swift Language Version**: 确保是 `Swift 5`
   - 搜索 **Other Linker Flags**: 添加 `-ObjC`（如果需要）

### 步骤 10：运行项目

1. 选择一个模拟器（如 iPhone 15 Pro）
2. 点击 **Run** 按钮（或按 ⌘R）
3. 首次运行可能需要接受网络连接权限

## 方法 2：使用提供的完整项目模板

如果你想直接使用一个完整的 Xcode 项目模板，可以：

1. 从 GitHub 下载预配置的 iOSWebBox 模板
2. 或者在 Mac 上运行以下命令：

```bash
cd /Users/zhengnan/Sniper/Developer/github/hybrid_framework

# 使用 Xcode 命令行工具（如果可用）
# 或者使用提供的自动化脚本
```

## 常见问题

### Q: 编译错误 "Cannot find 'Alamofire' in scope"
A: 确保已通过 SPM 添加 Alamofire，并在 Target 的 "Frameworks, Libraries, and Embedded Content" 中添加。

### Q: 运行时 WebView 显示空白
A: 检查 HTML 文件是否正确添加到 Bundle，并确保路径正确。

### Q: 插件调用失败
A: 确保所有插件都已注册，并且 JS SDK 已正确加载。

### Q: 相机/相册权限被拒绝
A: 在真机上测试，并在 Info.plist 中添加权限描述。

## 测试建议

### 在模拟器上测试
- ✅ Device Plugin
- ✅ Network Plugin
- ✅ WebView 基础功能
- ❌ Camera Plugin（模拟器不支持）
- ❌ Gallery Plugin（模拟器有限支持）

### 在真机上测试
- ✅ 所有功能完整测试

## 下一步

运行成功后，你可以：

1. 修改 `index.html` 测试不同的 API
2. 将 `defaultURL` 改为你的远程 H5 页面
3. 开发自定义插件
4. 集成到你的实际项目中

## 获取帮助

如果遇到问题：
1. 检查 Xcode 版本（推荐 14.0+）
2. 检查 iOS 部署目标（14.0+）
3. 清理项目（Product → Clean Build Folder）
4. 删除 Derived Data
5. 查看完整的编译错误信息
