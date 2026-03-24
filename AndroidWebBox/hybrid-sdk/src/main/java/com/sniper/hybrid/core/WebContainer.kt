package com.sniper.hybrid.core

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.AttributeSet
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import com.sniper.hybrid.HybridConfig
import com.sniper.hybrid.plugin.PluginContext
import java.io.File

/**
 * 增强的WebView容器
 */
class WebContainer @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : WebView(context, attrs, defStyleAttr) {

    private var config: HybridConfig? = null
    private var jsBridge: JSBridge? = null
    private var pluginContext: PluginContext? = null

    // 自定义拦截器
    private var urlInterceptor: ((String) -> Boolean)? = null
    private var errorListener: ((Int, String?) -> Unit)? = null

    /**
     * 初始化
     */
    fun init(config: HybridConfig, lifecycleOwner: androidx.lifecycle.LifecycleOwner) {
        this.config = config

        // 初始化JSBridge
        this.jsBridge = JSBridge(this).apply {
            init()
            setPluginContext(PluginContext(context, this@WebContainer, lifecycleOwner))
        }
        this.pluginContext = jsBridge?.getPluginManager()?.let {
            PluginContext(context, this, lifecycleOwner)
        }

        // 配置WebView设置
        setupWebViewSettings(config)

        // 设置WebViewClient
        setupWebViewClient(config)

        // 设置WebChromeClient
        setupWebChromeClient()
    }

    /**
     * 配置WebView设置
     */
    private fun setupWebViewSettings(config: HybridConfig) {
        settings.apply {
            // 基础设置
            javaScriptEnabled = true
            javaScriptCanOpenWindowsAutomatically = true

            // 缓存设置
            cacheMode = config.cacheMode
            domStorageEnabled = config.enableDomStorage
            databaseEnabled = config.enableDatabase

            // 文件访问
            allowFileAccess = config.allowFileAccess
            allowContentAccess = config.allowContentAccess

            // 其他设置
            loadWithOverviewMode = true
            useWideViewPort = true
            builtInZoomControls = false
            displayZoomControls = false
            mediaPlaybackRequiresUserGesture = false

            // 混合内容模式
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
                setMixedContentMode(config.mixedContentMode)
            }

            // UserAgent
            config.userAgent?.let {
                userAgentString = it
            }
        }
    }

    /**
     * 设置WebViewClient
     */
    private fun setupWebViewClient(config: HybridConfig) {
        webViewClient = object : WebViewClient() {

            override fun shouldOverrideUrlLoading(
                view: WebView?,
                request: WebResourceRequest?
            ): Boolean {
                val url = request?.url?.toString() ?: return false

                // 检查URL白名单
                if (!config.isUrlAllowed(url)) {
                    return true
                }

                // 自定义URL拦截
                urlInterceptor?.let {
                    if (it(url)) {
                        return true
                    }
                }

                // 处理特殊协议
                return when {
                    url.startsWith("tel:") -> {
                        context.startActivity(Intent(Intent.ACTION_DIAL, Uri.parse(url)))
                        true
                    }
                    url.startsWith("mailto:") -> {
                        context.startActivity(Intent(Intent.ACTION_SENDTO, Uri.parse(url)))
                        true
                    }
                    url.startsWith("intent://") -> {
                        try {
                            val intent = Intent.parseUri(url, Intent.URI_INTENT_SCHEME)
                            context.startActivity(intent)
                            true
                        } catch (e: Exception) {
                            false
                        }
                    }
                    else -> false
                }
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                // 页面加载完成后重新注入JS SDK
                jsBridge?.let {
                    it.init()
                }
            }

            override fun onReceivedError(
                view: WebView?,
                request: WebResourceRequest?,
                error: android.webkit.WebResourceError?
            ) {
                super.onReceivedError(view, request, error)
                // 自定义错误处理
                errorListener?.invoke(error?.errorCode ?: 0, error?.description?.toString())
            }
        }
    }

    /**
     * 设置WebChromeClient
     */
    private fun setupWebChromeClient() {
        webChromeClient = object : WebChromeClient() {

            override fun onProgressChanged(view: WebView?, newProgress: Int) {
                super.onProgressChanged(view, newProgress)
                // 可以在这里通知加载进度
            }

            override fun onReceivedTitle(view: WebView?, title: String?) {
                super.onReceivedTitle(view, title)
                // 可以在这里更新标题
            }

            override fun onGeolocationPermissionsShowPrompt(
                origin: String?,
                callback: android.webkit.GeolocationPermissions.Callback?
            ) {
                // 自动授予地理位置权限
                callback?.invoke(origin, true, false)
            }
        }
    }

    /**
     * 加载URL（带白名单检查）
     */
    fun loadHybridUrl(url: String) {
        if (config?.isUrlAllowed(url) == true) {
            super.loadUrl(url)
        }
    }

    /**
     * 获取JSBridge实例
     */
    fun getJSBridge(): JSBridge? = jsBridge

    /**
     * 获取插件管理器
     */
    fun getPluginManager() = jsBridge?.getPluginManager()

    /**
     * 设置URL拦截器
     */
    fun setUrlInterceptor(interceptor: (String) -> Boolean) {
        this.urlInterceptor = interceptor
    }

    /**
     * 设置错误监听器
     */
    fun setErrorListener(listener: (Int, String?) -> Unit) {
        this.errorListener = listener
    }

    /**
     * 处理Activity结果
     */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        jsBridge?.getPluginManager()?.onActivityResult(requestCode, resultCode, data)
    }

    /**
     * 处理权限结果
     */
    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        jsBridge?.getPluginManager()?.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    /**
     * 清理资源
     */
    fun cleanup() {
        jsBridge?.getPluginManager()?.unregisterAll()
    }
}
