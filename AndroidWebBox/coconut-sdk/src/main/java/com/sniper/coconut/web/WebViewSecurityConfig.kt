package com.sniper.coconut.web

import android.webkit.WebSettings
import android.webkit.WebView
import com.sniper.coconut.utils.Logger

/**
 * WebView Security Configuration
 *
 * Applies secure default settings to WebView to prevent common vulnerabilities.
 */
object WebViewSecurityConfig {

    private const val TAG = "WebViewSecurity"

    /**
     * Apply secure default settings to WebView
     *
     * @param webView WebView instance
     * @param allowFileAccess Whether to allow file:// access (default: false)
     * @param allowContentAccess Whether to allow content:// access (default: false)
     */
    fun applySecureDefaults(
        webView: WebView,
        allowFileAccess: Boolean = false,
        allowContentAccess: Boolean = false
    ) {
        Logger.d(TAG, "Applying secure WebView defaults")

        val settings = webView.settings

        // ---- Enabled features ----
        settings.javaScriptEnabled = true        // Required for hybrid apps
        settings.domStorageEnabled = true         // Required for modern web apps
        settings.databaseEnabled = true
        settings.setSupportZoom(true)
        settings.builtInZoomControls = true
        settings.displayZoomControls = false
        settings.loadWithOverviewMode = true
        settings.useWideViewPort = true

        // ---- Security: Disable dangerous features ----
        settings.allowFileAccess = allowFileAccess
        settings.allowContentAccess = allowContentAccess
        settings.allowFileAccessFromFileURLs = false   // Prevent file:// XSS
        settings.allowUniversalAccessFromFileURLs = false  // Prevent file:// XSS

        // ---- Cache & rendering ----
        settings.cacheMode = WebSettings.LOAD_DEFAULT
        settings.mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW

        // ---- Performance ----
        settings.setRenderPriority(WebSettings.RenderPriority.HIGH)

        Logger.d(TAG, "Secure WebView defaults applied")
    }
}
