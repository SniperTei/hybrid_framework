package com.sniper.coconut.bridge

import android.webkit.WebView

/**
 * Coconut Bridge Interface
 *
 * Defines the contract for H5-Native communication
 * Component-based architecture - components managed by ComponentManager
 */
interface CoconutBridge {

    /**
     * Handle incoming JavaScript call
     *
     * @param webView The WebView instance (for calling JS back)
     * @param jsonData JSON-RPC 2.0 request string
     * @param currentUrl Current page URL cached from main thread (avoid thread violation)
     * @return JSON-RPC 2.0 response string
     */
    fun handleCall(webView: WebView, jsonData: String, currentUrl: String = ""): String

    /**
     * Call JavaScript function (Native → H5)
     *
     * @param webView The WebView instance
     * @param functionName JavaScript function name
     * @param params Parameters
     */
    fun callJS(webView: WebView, functionName: String, params: Map<String, Any?>)

    /**
     * Cleanup resources
     */
    fun cleanup()
}
