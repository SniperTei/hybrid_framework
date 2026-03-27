package com.sniper.androidwebbox

import android.os.Bundle
import android.webkit.JavascriptInterface
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.appcompat.app.AppCompatActivity
import com.sniper.coconut.bridge.CoconutBridgeImpl
import com.sniper.coconut.component.ComponentManager
import com.sniper.coconut.utils.Logger

/**
 * MainActivity - Coconut SDK WebView 示例
 *
 * 展示如何使用 Coconut SDK 与 H5 页面进行交互
 *
 * 功能：
 * - 加载本地 H5 测试页面
 * - 注入 JavaScript 桥接
 * - 处理 WebView 返回事件
 *
 * 注意：Coconut SDK 的初始化和组件注册已在 WebBoxApplication 中完成
 */
class MainActivity : AppCompatActivity() {

    private lateinit var webView: WebView
    private lateinit var bridge: CoconutBridgeImpl

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        Logger.i("MainActivity", "Activity onCreate")

        // 设置 WebView
        setupWebView()

        // 加载测试页面
        loadTestPage()
    }

    /**
     * 设置 WebView
     */
    private fun setupWebView() {
        webView = WebView(this)

        // 配置 WebView 设置
        val settings = webView.settings
        settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            databaseEnabled = true
            setSupportZoom(true)
            builtInZoomControls = true
            displayZoomControls = false
            cacheMode = android.webkit.WebSettings.LOAD_DEFAULT
            // 允许从 file:// 加载的资源访问其他文件
            allowFileAccessFromFileURLs = true
            allowUniversalAccessFromFileURLs = true
            // 允许混合内容（HTTP + HTTPS）
            mixedContentMode = android.webkit.WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
        }

        // 设置 WebViewClient
        webView.webViewClient = object : WebViewClient() {
            override fun onPageStarted(view: WebView?, url: String?, favicon: android.graphics.Bitmap?) {
                super.onPageStarted(view, url, favicon)
                Logger.d("MainActivity", "Page started: $url")
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                Logger.d("MainActivity", "Page finished: $url")

                // 页面加载完成后，延迟注入桥接 JavaScript，确保页面 JS 已初始化
                view?.postDelayed({
                    injectBridgeJavaScript()
                    Logger.d("MainActivity", "Bridge JavaScript injected")
                }, 100)
            }

            override fun onReceivedError(view: WebView?, request: WebResourceRequest?, error: WebResourceError?) {
                super.onReceivedError(view, request, error)
                Logger.e("MainActivity", "Page error: ${error?.description}")
                Logger.e("MainActivity", "Failed URL: ${request?.url}")
            }

            override fun onReceivedHttpError(
                view: WebView?,
                request: WebResourceRequest?,
                errorResponse: WebResourceResponse?
            ) {
                super.onReceivedHttpError(view, request, errorResponse)
                Logger.e("MainActivity", "HTTP error: ${errorResponse?.statusCode}")
            }
        }

        // 设置为内容视图
        setContentView(webView)

        // 创建桥接实例
        bridge = CoconutBridgeImpl(ComponentManager.getInstance())

        // 添加 JavaScript 接口
        webView.addJavascriptInterface(
            object {
                @JavascriptInterface
                fun call(jsonData: String): String {
                    return bridge.handleCall(webView, jsonData)
                }
            },
            "CoconutBridge"
        )

        Logger.d("MainActivity", "WebView setup complete")
    }

    /**
     * 注入桥接 JavaScript
     * 注意：H5 页面已经有 coconut.js，这里只需要确认 CoconutBridge 接口可用
     */
    private fun injectBridgeJavaScript() {
        // 检查 Coconut 对象是否已存在
        val checkScript = """
            (function() {
                if (typeof window.Coconut !== 'undefined') {
                    console.log('✅ Coconut SDK already loaded');
                    console.log('📱 Environment:', window.Coconut.env?.platform || 'unknown');
                    console.log('🔗 CoconutBridge available:', typeof window.CoconutBridge !== 'undefined');
                    return 'Coconut exists';
                } else {
                    console.error('❌ Coconut SDK not found');
                    return 'Coconut not found';
                }
            })();
        """.trimIndent()

        webView.evaluateJavascript(checkScript) { result ->
            Logger.d("MainActivity", "Coconut SDK check: $result")
        }

        Logger.d("MainActivity", "Bridge JavaScript check complete")
    }

    /**
     * 加载测试页面
     */
    private fun loadTestPage() {
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

        Logger.d("MainActivity", "Running on emulator: $isEmulator")
        Logger.d("MainActivity", "Loading URL: $url")

        webView.loadUrl(url)

        // 生产环境：从 assets 加载本地 HTML
        // webView.loadUrl("file:///android_asset/index.html")
    }

    override fun onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack()
        } else {
            super.onBackPressed()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        Logger.d("MainActivity", "Activity destroyed")
    }
}
