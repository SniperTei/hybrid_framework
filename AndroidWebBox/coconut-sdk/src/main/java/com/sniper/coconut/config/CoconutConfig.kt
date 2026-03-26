package com.sniper.coconut.config

/**
 * Coconut SDK Configuration
 *
 * Provides configuration options for the SDK
 */
class CoconutConfig {

    /**
     * Debug mode
     * When enabled, logs are verbose
     */
    var isDebugMode: Boolean = true
        private set

    /**
     * Request timeout in milliseconds
     */
    var timeout: Long = 30000
        private set

    /**
     * Enable auto-registration of built-in components
     */
    var autoRegisterComponents: Boolean = true
        private set

    /**
     * Custom user agent for WebView
     */
    var customUserAgent: String? = null
        private set

    /**
     * Enable WebView debugging
     */
    var enableWebViewDebug: Boolean = false
        private set

    /**
     * Set debug mode
     */
    fun setDebugMode(debug: Boolean) = apply {
        isDebugMode = debug
    }

    /**
     * Set request timeout
     */
    fun setTimeout(milliseconds: Long) = apply {
        timeout = milliseconds
    }

    /**
     * Set auto-registration of built-in components
     */
    fun setAutoRegisterComponents(enable: Boolean) = apply {
        autoRegisterComponents = enable
    }

    /**
     * Set custom user agent for WebView
     */
    fun setCustomUserAgent(agent: String) = apply {
        customUserAgent = agent
    }

    /**
     * Enable WebView debugging
     */
    fun setEnableWebViewDebug(enable: Boolean) = apply {
        enableWebViewDebug = enable
    }

    /**
     * Apply configuration
     * Called after all configuration options are set
     */
    internal fun apply() {
        com.sniper.coconut.utils.Logger.setDebugMode(isDebugMode)

        if (enableWebViewDebug) {
            android.webkit.WebView.setWebContentsDebuggingEnabled(true)
        }
    }
}
