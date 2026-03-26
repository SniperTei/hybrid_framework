package com.sniper.coconut.web

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.webkit.WebView
import android.webkit.WebViewClient
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebResourceError
import android.webkit.JavascriptInterface
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import com.sniper.coconut.CoconutSDK
import com.sniper.coconut.bridge.CoconutBridgeImpl
import com.sniper.coconut.component.ComponentManager
import com.sniper.coconut.utils.Logger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

/**
 * CoconutWebActivity - Coconut SDK WebView Activity
 *
 * 提供开箱即用的 WebView Activity，支持加载 H5 页面并使用 Coconut 组件
 *
 * 使用方式：
 * ```kotlin
 * // 方式1：静态启动（最简单）
 * CoconutWebActivity.start(context, "https://example.com")
 *
 * // 方式2：带回调
 * CoconutWebActivity.startForResult(activity, url, requestCode)
 *
 * // 方式3：继承定制
 * class MyActivity : CoconutWebActivity() {
 *     override fun onPageFinished(url: String) {
 *         // 自定义逻辑
 *     }
 * }
 * ```
 */
open class CoconutWebActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "CoconutWebActivity"
        private const val EXTRA_URL = "extra_url"
        private const val EXTRA_ENABLE_DEBUG = "extra_enable_debug"
        private const val EXTRA_USER_AGENT = "extra_user_agent"

        /**
         * 启动 WebView Activity
         *
         * @param context 上下文
         * @param url 要加载的 URL
         */
        @JvmStatic
        fun start(context: Context, url: String) {
            val intent = Intent(context, CoconutWebActivity::class.java)
            intent.putExtra(EXTRA_URL, url)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        }

        /**
         * 启动 WebView Activity（带调试选项）
         *
         * @param context 上下文
         * @param url 要加载的 URL
         * @param enableDebug 是否启用调试
         */
        @JvmStatic
        fun start(context: Context, url: String, enableDebug: Boolean) {
            val intent = Intent(context, CoconutWebActivity::class.java)
            intent.putExtra(EXTRA_URL, url)
            intent.putExtra(EXTRA_ENABLE_DEBUG, enableDebug)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        }

        /**
         * 启动 WebView Activity（带自定义 UserAgent）
         *
         * @param context 上下文
         * @param url 要加载的 URL
         * @param userAgent 自定义 UserAgent
         */
        @JvmStatic
        fun start(context: Context, url: String, userAgent: String) {
            val intent = Intent(context, CoconutWebActivity::class.java)
            intent.putExtra(EXTRA_URL, url)
            intent.putExtra(EXTRA_USER_AGENT, userAgent)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        }

        /**
         * 启动 WebView Activity（完整配置）
         *
         * @param context 上下文
         * @param url 要加载的 URL
         * @param enableDebug 是否启用调试
         * @param userAgent 自定义 UserAgent
         */
        @JvmStatic
        fun start(context: Context, url: String, enableDebug: Boolean = false, userAgent: String? = null) {
            val intent = Intent(context, CoconutWebActivity::class.java)
            intent.putExtra(EXTRA_URL, url)
            intent.putExtra(EXTRA_ENABLE_DEBUG, enableDebug)
            userAgent?.let {
                intent.putExtra(EXTRA_USER_AGENT, it)
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        }

        /**
         * 启动 WebView Activity（带结果返回）
         *
         * @param activity Activity
         * @param url 要加载的 URL
         * @param requestCode 请求码
         */
        @JvmStatic
        fun startForResult(activity: Activity, url: String, requestCode: Int) {
            val intent = Intent(activity, CoconutWebActivity::class.java)
            intent.putExtra(EXTRA_URL, url)
            activity.startActivityForResult(intent, requestCode)
        }
    }

    protected lateinit var webView: WebView
        private set

    protected lateinit var bridge: CoconutBridgeImpl
        private set

    private var currentUrl: String? = null
    private var enableDebug = false
    private var customUserAgent: String? = null

    // Activity 作用域
    private val activityScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        Logger.i(TAG, "onCreate")

        // 获取配置
        val url = intent.getStringExtra(EXTRA_URL)
        enableDebug = intent.getBooleanExtra(EXTRA_ENABLE_DEBUG, false)
        customUserAgent = intent.getStringExtra(EXTRA_USER_AGENT)

        if (url.isNullOrEmpty()) {
            Logger.e(TAG, "URL is empty")
            finish()
            return
        }

        currentUrl = url

        // 配置 SDK
        if (enableDebug) {
            CoconutSDK.configure {
                setDebugMode(true)
                setEnableWebViewDebug(true)
            }
        }

        // 设置 WebView
        setupWebView()

        // 加载 URL
        loadUrl(url)
    }

    /**
     * 设置 WebView
     * 子类可以重写此方法来自定义 WebView 配置
     */
    protected open fun setupWebView() {
        webView = WebView(this)

        val settings = webView.settings
        settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            databaseEnabled = true
            setSupportZoom(true)
            builtInZoomControls = true
            displayZoomControls = false
            cacheMode = android.webkit.WebSettings.LOAD_DEFAULT
        }

        // 设置自定义 UserAgent
        customUserAgent?.let {
            settings.userAgentString = it
        }

        // 设置 WebViewClient
        webView.webViewClient = createWebViewClient()

        // 设置为内容视图
        setContentView(webView)

        // 创建并配置桥接
        setupBridge()

        Logger.d(TAG, "WebView setup complete")
    }

    /**
     * 创建 WebViewClient
     * 子类可以重写此方法来自定义 WebViewClient 行为
     */
    protected open fun createWebViewClient(): WebViewClient {
        return object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                Logger.d(TAG, "Page loaded: $url")

                // 页面加载完成后注入桥接
                url?.let {
                    injectBridgeJavaScript()
                    onPageFinishedCallback(it)
                }
            }

            override fun onPageStarted(view: WebView?, url: String?, favicon: android.graphics.Bitmap?) {
                super.onPageStarted(view, url, favicon)
                Logger.d(TAG, "Page started: $url")
                onPageStartedCallback(url)
            }

            override fun onLoadResource(view: WebView?, url: String?) {
                super.onLoadResource(view, url)
                Logger.d(TAG, "Loading resource: $url")
            }

            override fun onReceivedError(view: WebView?, request: WebResourceRequest?, error: WebResourceError?) {
                super.onReceivedError(view, request, error)
                val errorUrl = request?.url?.toString() ?: "unknown"
                Logger.e(TAG, "Page error: $errorUrl, error: ${error?.description}")
                onPageErrorCallback(errorUrl, error)
            }
        }
    }

    /**
     * 创建桥接
     * 子类可以重写此方法来自定义桥接实现
     */
    protected open fun setupBridge() {
        bridge = CoconutBridgeImpl(ComponentManager.getInstance())

        webView.addJavascriptInterface(
            object {
                @JavascriptInterface
                fun call(jsonData: String): String {
                    return bridge.handleCall(webView, jsonData)
                }
            },
            "CoconutBridge"
        )

        Logger.d(TAG, "Bridge setup complete")
    }

    /**
     * 注入桥接 JavaScript
     * 子类可以重写此方法来自定义注入的 JavaScript 代码
     */
    protected open fun injectBridgeJavaScript() {
        val javascript = """
            (function() {
                // 创建全局 Coconut 对象
                window.Coconut = {
                    call: function(method, params, callback, timeout) {
                        var request = {
                            jsonrpc: "2.0",
                            method: method,
                            params: params || {},
                            id: Date.now().toString()
                        };

                        // 设置默认超时（如果未指定）
                        var to = timeout || 30000;

                        // 设置回调函数
                        var callbackId = 'callback_' + request.id;
                        window[callbackId] = callback;

                        // 设置超时
                        var timer = setTimeout(function() {
                            if (window[callbackId]) {
                                callback({ error: 'Timeout after ' + to + 'ms' }, true);
                                delete window[callbackId];
                            }
                        }, to);

                        // 调用 Android 桥接
                        if (window.CoconutBridge && window.CoconutBridge.call) {
                            var responseStr = CoconutBridge.call(JSON.stringify(request));

                            // 立即解析响应
                            try {
                                var response = JSON.parse(responseStr);
                                if (response && response.result && response.result.code === '000000') {
                                    // 成功，清除超时
                                    clearTimeout(timer);
                                    if (window[callbackId]) {
                                        callback(response, false);
                                        delete window[callbackId];
                                    }
                                } else if (response && response.error) {
                                    // 错误响应
                                    clearTimeout(timer);
                                    if (window[callbackId]) {
                                        callback(response, true);
                                        delete window[callbackId];
                                    }
                                }
                            } catch (e) {
                                // JSON 解析错误
                                clearTimeout(timer);
                                if (window[callbackId]) {
                                    callback({ error: 'Parse error: ' + e.message }, true);
                                    delete window[callbackId];
                                }
                            }
                        } else {
                            clearTimeout(timer);
                            callback({ error: 'CoconutBridge not found' }, true);
                        }
                    },

                    /**
                     * 异步调用（带回调）
                     */
                    callAsync: function(method, params) {
                        return new Promise(function(resolve, reject) {
                            this.call(method, params, function(response, isError) {
                                if (isError) {
                                    reject(response);
                                } else {
                                    resolve(response);
                                }
                            });
                        }.bind(this));
                    }
                };

                console.log('✅ Coconut SDK initialized');
                console.log('📱 Available methods: Coconut.call()');
                console.log('📱 Example: Coconut.call("device.getInfo", {}, console.log)');
            })();
        """.trimIndent()

        webView.evaluateJavascript(javascript, null)
        Logger.d(TAG, "Bridge JavaScript injected")
    }

    /**
     * 加载 URL
     *
     * @param url 要加载的 URL
     */
    protected open fun loadUrl(url: String) {
        Logger.d(TAG, "Loading URL: $url")
        webView.loadUrl(url)
    }

    /**
     * 重新加载当前页面
     */
    protected open fun reload() {
        currentUrl?.let {
            webView.reload()
        }
    }

    /**
     * 页面加载完成回调
     * 子类可以重写此方法来处理页面加载完成事件
     *
     * @param url 加载完成的 URL
     */
    protected open fun onPageFinishedCallback(url: String) {
        Logger.d(TAG, "Page finished: $url")
    }

    /**
     * 页面开始加载回调
     * 子类可以重写此方法来处理页面开始加载事件
     *
     * @param url 开始加载的 URL
     */
    protected open fun onPageStartedCallback(url: String?) {
        Logger.d(TAG, "Page started: $url")
    }

    /**
     * 页面加载错误回调
     * 子类可以重写此方法来处理页面加载错误
     *
     * @param url 出错的 URL
     * @param error 错误信息
     */
    protected open fun onPageErrorCallback(url: String, error: android.webkit.WebResourceError?) {
        Logger.e(TAG, "Page error: $url, error: ${error?.description}")
    }

    /**
     * 获取当前 URL
     *
     * @return 当前加载的 URL
     */
    protected fun getCurrentUrl(): String? = currentUrl

    /**
     * 评估 JavaScript 代码
     *
     * @param script JavaScript 代码
     */
    fun evaluateJavascript(script: String) {
        webView.evaluateJavascript(script, null)
    }

    /**
     * 返回上一页
     */
    override fun onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack()
        } else {
            super.onBackPressed()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        Logger.d(TAG, "onDestroy")
    }

    /**
     * 静态工具方法：获取 URL 的 HTML 内容
     *
     * @param url URL 地址
     * @param callback 回调函数
     */
    fun fetchUrlContent(url: String, callback: (String?) -> Unit) {
        activityScope.launch(Dispatchers.IO) {
            try {
                val connection = URL(url).openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.connectTimeout = 10000
                connection.readTimeout = 10000

                if (connection.responseCode == HttpURLConnection.HTTP_OK) {
                    val reader = BufferedReader(InputStreamReader(connection.inputStream))
                    val content = reader.use { it.readText() }
                    launch(Dispatchers.Main) {
                        callback(content)
                    }
                } else {
                    launch(Dispatchers.Main) {
                        callback(null)
                    }
                }
            } catch (e: Exception) {
                Logger.e(TAG, "Failed to fetch URL content", e)
                launch(Dispatchers.Main) {
                    callback(null)
                }
            }
        }
    }
}
