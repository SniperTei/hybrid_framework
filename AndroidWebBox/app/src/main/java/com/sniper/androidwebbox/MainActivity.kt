package com.sniper.androidwebbox

import android.os.Bundle
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.button.MaterialButton
import com.sniper.coconut.web.CoconutWebActivity
import com.sniper.coconut.utils.Logger

/**
 * MainActivity - Coconut SDK 演示应用
 *
 * 展示如何使用 Coconut SDK 的 CoconutWebActivity
 *
 * 功能：
 * - Hello World 欢迎页面
 * - 按钮启动 Coconut WebView（加载远程 H5）
 * - 按钮启动本地测试页面
 *
 * 注意：Coconut SDK 的初始化和组件注册已在 WebBoxApplication 中完成
 */
class MainActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        Logger.i("MainActivity", "Activity onCreate")

        // 初始化视图
        setupViews()
    }

    /**
     * 设置视图和点击事件
     */
    private fun setupViews() {
        // 打开 Coconut WebView 按钮（加载远程 H5）
        findViewById<MaterialButton>(R.id.btnOpenWebView).setOnClickListener {
            openCoconutWebView()
        }

        // 打开本地测试页面按钮
        findViewById<MaterialButton>(R.id.btnOpenLocal).setOnClickListener {
            openLocalTestPage()
        }

        Logger.d("MainActivity", "Views setup complete")
    }

    /**
     * 打开 Coconut WebView（加载远程 H5 页面）
     *
     * 使用 CoconutWebActivity 加载 coconutWebBox Vue 项目
     */
    private fun openCoconutWebView() {
        // 检测是否在模拟器中运行
        val isEmulator = android.os.Build.FINGERPRINT.startsWith("generic") ||
                         android.os.Build.FINGERPRINT.startsWith("unknown") ||
                         android.os.Build.MODEL.contains("google_sdk") ||
                         android.os.Build.MODEL.contains("Emulator") ||
                         android.os.Build.MODEL.contains("Android SDK built for x86")

        val url = if (isEmulator) {
            // 模拟器使用特殊地址访问宿主机
            "http://10.0.2.2:5174"
        } else {
            // 真机使用实际 IP
            "http://192.168.229.128:5174"
        }

        Logger.d("MainActivity", "Opening Coconut WebView: $url")
        Logger.d("MainActivity", "Running on emulator: $isEmulator")

        // 使用 CoconutWebActivity 打开 WebView
        CoconutWebActivity.start(this, url, enableDebug = true)

        Toast.makeText(this, "正在打开 Coconut WebView...", Toast.LENGTH_SHORT).show()
    }

    /**
     * 打开本地测试页面
     *
     * 使用 CoconutWebActivity 加载 assets 中的本地 HTML
     */
    private fun openLocalTestPage() {
        val url = "file:///android_asset/index.html"

        Logger.d("MainActivity", "Opening local test page: $url")

        // 使用 CoconutWebActivity 打开本地页面
        CoconutWebActivity.start(this, url)

        Toast.makeText(this, "正在打开本地测试页面...", Toast.LENGTH_SHORT).show()
    }

    override fun onDestroy() {
        super.onDestroy()
        Logger.d("MainActivity", "Activity destroyed")
    }
}
