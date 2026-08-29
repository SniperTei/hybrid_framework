//
//  SceneDelegate.swift
//  iOSWebBox
//
//  Created by zhengnan on 2026/3/29.
//

import UIKit
import CoconutSDK

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        // Initialize Coconut SDK
        CoconutSDK.configure { config in
            config.debugMode = true
            config.environment = .dev
        }

        let window = UIWindow(windowScene: windowScene)
        self.window = window
        window.makeKeyAndVisible()

        // Initialize SDK + register components FIRST, then load the H5 page so
        // the bridge is ready when coconut_index.html fires its first call.
        Task {
            await CoconutSDK.initialize()

            // Explicit registration (mirrors Android's WebBoxApplication).
            // The host app decides which components are active.
            await CoconutSDK.registerComponents([
                DeviceComponent(),
                StorageComponent(),
                EventComponent(),
                DialogComponent(),
                NetworkComponent(),
                NavigatorComponent(),
                UpdateComponent(),   // 热更新（iOS 空实现：App Store 2.5.2，业务层 success:false）
            ])

            // 启动期 eager 模板校验：重复名 / 解析不了的类 / 非 CoconutWebViewController
            // 子类都在 launch 时炸出来，而不是等到 forward 才发现（fail-fast）。
            do {
                try TemplateRegistry.shared.validateEagerly()
            } catch {
                NSLog("[TemplateRegistry] eager validation failed: \(error.localizedDescription)")
            }

            await MainActor.run {
                // 入口页（带两个按钮：bundle HTML / dev server），
                // 对标 Android MainActivity。SDK 在 loadUrl 前已注册完组件。
                //
                // Debug-only deep link: launch with `-coconutUrl <URL>` to skip
                // the menu and present CoconutWebViewController directly. Used
                // for automated e2e testing (no accessibility permission for UI
                // automation). Production builds never set this launch arg.
                let env = ProcessInfo.processInfo.environment
                if let directURL = env["COCONUT_URL"] ?? env["coconutUrl"], !directURL.isEmpty {
                    let webVC = CoconutWebViewController()
                    webVC.enableDebug = true
                    window.rootViewController = webVC
                    webVC.loadUrl(directURL)
                } else {
                    window.rootViewController = HomeViewController()
                }

                // Debug-only hot-update e2e hooks (same spirit as COCONUT_URL):
                //   COCONUT_UPDATE_URL=<manifest url>  → check + auto-apply for module "demo"
                //   COCONUT_ROLLBACK=1                 → rollback module "demo"
                // Production builds never set these.
                if let updateUrl = env["COCONUT_UPDATE_URL"], !updateUrl.isEmpty {
                    Task {
                        let check = await CoconutUpdateManager.shared.checkUpdate(moduleId: "demo", manifestUrl: updateUrl)
                        print("[E2E] checkUpdate: available=\(check.available) current=\(check.currentVersion) remote=\(check.remoteVersion) error=\(check.error ?? "nil")")
                        guard check.available, let manifest = check.manifest else { return }
                        // NSString.deletingLastPathComponent collapses "//" → "/"
                        // (path semantics), breaking http:// URLs — strip the last
                        // path segment manually instead.
                        let baseUrl = String(updateUrl[..<(updateUrl.lastIndex(of: "/") ?? updateUrl.startIndex)])
                        let result = await CoconutUpdateManager.shared.performUpdate(manifest: manifest, baseUrl: baseUrl)
                        print("[E2E] performUpdate: success=\(result.success) version=\(result.version) error=\(result.error ?? "nil")")
                    }
                }
                if env["COCONUT_ROLLBACK"] == "1" {
                    Task {
                        let ok = await CoconutUpdateManager.shared.rollback(moduleId: "demo")
                        let version = CoconutUpdateManager.shared.currentVersion(moduleId: "demo")
                        print("[E2E] rollback: success=\(ok) version=\(version)")
                    }
                }
            }
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}

