package com.sniper.androidwebbox

import android.os.Bundle
import android.webkit.JavascriptInterface
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.appcompat.app.AppCompatActivity
import com.sniper.coconut.bridge.CoconutBridgeImpl
import com.sniper.coconut.component.ComponentManager
import com.sniper.coconut.utils.Logger

/**
 * MainActivity - Coconut SDK 测试入口
 *
 * 注意：Coconut SDK 的初始化和组件注册已在 WebBoxApplication 中完成
 * 这里只需要设置 WebView 并加载测试页面
 */
class MainActivity : AppCompatActivity() {

    private lateinit var webView: WebView
    private lateinit var bridge: CoconutBridgeImpl

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        Logger.i("MainActivity", "MainActivity onCreate")

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
            setSupportZoom(true)
            builtInZoomControls = true
            displayZoomControls = false
        }

        // 设置 WebViewClient
        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                Logger.d("MainActivity", "Page loaded: $url")

                // 页面加载完成后注入桥接 JavaScript
                injectBridgeJavaScript()
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
     */
    private fun injectBridgeJavaScript() {
        val javascript = """
            (function() {
                // 创建全局 Coconut 对象供 H5 调用
                window.Coconut = {
                    call: function(method, params, callback) {
                        var request = {
                            jsonrpc: "2.0",
                            method: method,
                            params: params || {},
                            id: Date.now().toString()
                        };

                        // 设置回调函数
                        window.__coconutCallback = function(responseStr) {
                            if (callback) {
                                var response;
                                try {
                                    response = JSON.parse(responseStr);
                                } catch (e) {
                                    response = { error: 'Parse error: ' + e.message };
                                }
                                callback(response);
                            }
                        };

                        // 调用 Android 桥接
                        if (window.CoconutBridge && window.CoconutBridge.call) {
                            CoconutBridge.call(JSON.stringify(request));
                        } else {
                            console.error('CoconutBridge not available');
                            callback({ error: 'CoconutBridge not found' });
                        }
                    }
                };

                console.log('✅ Coconut SDK bridge initialized');
            })();
        """.trimIndent()

        webView.evaluateJavascript(javascript, null)
        Logger.d("MainActivity", "Bridge JavaScript injected")
    }

    /**
     * 加载测试页面
     */
    private fun loadTestPage() {
        // 从 assets 加载 index.html
        webView.loadUrl("file:///android_asset/index.html")
        Logger.d("MainActivity", "Loading test page from assets")
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
        Logger.d("MainActivity", "MainActivity destroyed")
    }
}
