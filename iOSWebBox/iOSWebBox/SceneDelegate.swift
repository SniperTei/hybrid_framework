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
            ])

            await MainActor.run {
                // 入口页（带两个按钮：bundle HTML / dev server），
                // 对标 Android MainActivity。SDK 在 loadUrl 前已注册完组件。
                window.rootViewController = HomeViewController()
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

