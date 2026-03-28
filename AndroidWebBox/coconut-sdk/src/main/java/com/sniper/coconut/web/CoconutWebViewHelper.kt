package com.sniper.coconut.web

import android.webkit.WebView
import com.sniper.coconut.bridge.CoconutBridge
import com.sniper.coconut.bridge.CoconutBridgeImpl
import com.sniper.coconut.component.ComponentManager
import com.sniper.coconut.config.CoconutConfig
import com.sniper.coconut.utils.Logger

/**
 * Coconut WebView Helper
 *
 * Helper class for WebView integration with Coconut SDK.
 * Applies secure defaults and attaches the bridge.
 */
class CoconutWebViewHelper private constructor() {

    private var config: CoconutConfig? = null

    /**
     * Configure WebView with Coconut SDK secure defaults
     */
    fun configureWebView(webView: WebView, config: CoconutConfig) {
        this.config = config

        WebViewSecurityConfig.applySecureDefaults(webView)

        // Custom user agent
        config.customUserAgent?.let {
            webView.settings.userAgentString = it
        }

        Logger.d("CoconutWebViewHelper", "WebView configured with secure defaults")
    }

    /**
     * Attach bridge to WebView
     */
    fun attachBridge(webView: WebView, bridge: CoconutBridge) {
        webView.addJavascriptInterface(
            CoconutJSBridge(bridge, webView),
            "CoconutBridge"
        )
        Logger.d("CoconutWebViewHelper", "Bridge attached to WebView")
    }

    /**
     * Create and attach bridge with default ComponentManager
     */
    fun attachDefaultBridge(webView: WebView): CoconutBridge {
        val bridge = CoconutBridgeImpl(ComponentManager.getInstance())
        attachBridge(webView, bridge)
        return bridge
    }

    /**
     * Inject JavaScript code
     */
    fun injectJavaScript(webView: WebView, javascript: String) {
        webView.evaluateJavascript(javascript, null)
        Logger.d("CoconutWebViewHelper", "JavaScript injected")
    }

    /**
     * Load URL
     */
    fun loadUrl(webView: WebView, url: String) {
        webView.loadUrl(url)
        Logger.d("CoconutWebViewHelper", "Loading URL: $url")
    }

    /**
     * Load HTML data
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
 * Fixed: now holds a reference to WebView for proper bridge calls.
 */
internal class CoconutJSBridge(
    private val bridge: CoconutBridge,
    private val webView: WebView
) {
    @Volatile
    var cachedUrl: String = ""

    @android.webkit.JavascriptInterface
    fun call(jsonData: String): String {
        return bridge.handleCall(webView, jsonData, cachedUrl)
    }
}
