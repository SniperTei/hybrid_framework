package com.sniper.coconut.web

import android.content.Context
import android.webkit.WebSettings
import android.webkit.WebView
import com.sniper.coconut.bridge.CoconutBridge
import com.sniper.coconut.bridge.CoconutBridgeImpl
import com.sniper.coconut.component.ComponentManager
import com.sniper.coconut.config.CoconutConfig
import com.sniper.coconut.utils.Logger

/**
 * Coconut WebView Helper
 *
 * Helper class for WebView integration with Coconut SDK
 */
class CoconutWebViewHelper private constructor() {

    private var config: CoconutConfig? = null

    /**
     * Configure WebView with Coconut SDK
     *
     * @param webView WebView instance
     * @param config SDK configuration
     */
    fun configureWebView(webView: WebView, config: CoconutConfig) {
        this.config = config

        val settings = webView.settings
        settings.apply {
            // Enable JavaScript
            javaScriptEnabled = true

            // Enable DOM Storage
            domStorageEnabled = true

            // Enable Database
            databaseEnabled = true

            // Set cache mode
            cacheMode = WebSettings.LOAD_DEFAULT

            // Enable zoom
            setSupportZoom(true)
            builtInZoomControls = true
            displayZoomControls = false

            // Improve rendering
            setRenderPriority(WebSettings.RenderPriority.HIGH)
            // setAppCacheEnabled is deprecated and removed in API 35
            // setAppCacheEnabled(true)

            // Enable mixed content (for HTTPS pages loading HTTP resources)
            mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW

            // Custom user agent
            config.customUserAgent?.let {
                userAgentString = it
            }
        }

        Logger.d("CoconutWebViewHelper", "WebView configured")
    }

    /**
     * Attach bridge to WebView
     *
     * @param webView WebView instance
     * @param bridge Bridge instance
     */
    fun attachBridge(webView: WebView, bridge: CoconutBridge) {
        webView.addJavascriptInterface(
            CoconutJSBridge(bridge),
            "CoconutBridge"
        )
        Logger.d("CoconutWebViewHelper", "Bridge attached to WebView")
    }

    /**
     * Create and attach bridge with default ComponentManager
     *
     * @param webView WebView instance
     * @return Bridge instance
     */
    fun attachDefaultBridge(webView: WebView): CoconutBridge {
        val bridge = CoconutBridgeImpl(ComponentManager.getInstance())
        attachBridge(webView, bridge)
        return bridge
    }

    /**
     * Inject JavaScript bridge initialization code
     *
     * @param webView WebView instance
     * @param javascript JavaScript code to inject
     */
    fun injectJavaScript(webView: WebView, javascript: String) {
        webView.evaluateJavascript(javascript, null)
        Logger.d("CoconutWebViewHelper", "JavaScript injected")
    }

    /**
     * Load URL in WebView
     *
     * @param webView WebView instance
     * @param url URL to load
     */
    fun loadUrl(webView: WebView, url: String) {
        webView.loadUrl(url)
        Logger.d("CoconutWebViewHelper", "Loading URL: $url")
    }

    /**
     * Load HTML data in WebView
     *
     * @param webView WebView instance
     * @param data HTML data
     * @param mimeType MIME type
     * @param encoding Encoding
     */
    fun loadData(webView: WebView, data: String, mimeType: String = "text/html", encoding: String = "UTF-8") {
        webView.loadData(data, mimeType, encoding)
        Logger.d("CoconutWebViewHelper", "Loaded HTML data")
    }

    companion object {
        @Volatile
        private var instance: CoconutWebViewHelper? = null

        fun getInstance(): CoconutWebViewHelper {
            return instance ?: synchronized(this) {
                instance ?: CoconutWebViewHelper().also { instance = it }
            }
        }
    }
}

/**
 * JavaScript Bridge Interface for WebView
 *
 * Exposed to JavaScript as "CoconutBridge"
 */
internal class CoconutJSBridge(private val bridge: CoconutBridge) {

    @android.webkit.JavascriptInterface
    fun call(jsonData: String): String {
        return bridge.handleCall(getWebView(), jsonData)
    }

    private fun getWebView(): WebView {
        // This is a placeholder - in real implementation,
        // you need to get the WebView instance from context
        throw UnsupportedOperationException("Use CoconutBridge.handleCall directly")
    }
}
