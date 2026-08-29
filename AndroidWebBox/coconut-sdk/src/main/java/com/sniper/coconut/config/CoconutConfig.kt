package com.sniper.coconut.config

import com.sniper.coconut.nav.NavConfig
import com.sniper.coconut.utils.Logger

/**
 * Coconut SDK Configuration
 *
 * Provides configuration options for the SDK including
 * multi-environment support, debug mode, and security settings.
 */
class CoconutConfig {

    // ---- Basic Settings ----

    /**
     * Debug mode - enables verbose logging
     */
    var isDebugMode: Boolean = true
        private set

    /**
     * Request timeout in milliseconds
     */
    var timeout: Long = 30000
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

    // ---- Environment Settings ----

    /**
     * Current environment
     */
    var environment: Environment = Environment.DEV
        private set

    /**
     * H5 domain override (if null, uses environment default)
     */
    var h5Domain: String? = null
        private set

    /**
     * API domain override (if null, uses environment default)
     */
    var apiDomain: String? = null
        private set

    // ---- Security Settings ----

    /**
     * Domain whitelist for Bridge calls (empty = allow all)
     */
    var allowedDomains: List<String> = emptyList()
        private set

    /**
     * Enable Bridge parameter validation
     */
    var enableParamValidation: Boolean = true
        private set

    /**
     * Max params size in bytes for Bridge calls
     */
    var maxBridgeParamsSize: Int = 1024 * 1024 // 1MB
        private set

    /**
     * Enable rate limiting for Bridge calls
     */
    var enableRateLimit: Boolean = true
        private set

    /**
     * SDK version string
     */
    var sdkVersion: String = "3.5.0"
        private set

    // ---- Security Enhancement Settings ----

    /**
     * Enable bridge token validation (JS injection protection)
     */
    var enableBridgeToken: Boolean = true
        private set

    // ---- Container Navigation Settings (v3.5.0) ----

    /**
     * Global default navigation-bar config for CoconutWebActivity.
     * Per-open overrides (template subclass default / forward header) merge
     * on top of this field-by-field (null = inherit).
     */
    var nav: NavConfig = NavConfig.default()
        private set

    /**
     * Show a native error dialog on main-frame network-level load failure
     * (white-screen rescue). Independent of nav visibility; not per-open
     * overridable.
     */
    var enableErrorDialog: Boolean = true
        private set

    // ---- Convenience Getters ----

    /**
     * Get effective H5 domain (override > environment default)
     */
    val effectiveH5Domain: String
        get() = h5Domain ?: environment.defaultH5Domain

    /**
     * Get effective API domain (override > environment default)
     */
    val effectiveApiDomain: String
        get() = apiDomain ?: environment.defaultApiDomain

    // ---- DSL Setters ----

    fun setDebugMode(debug: Boolean) = apply {
        isDebugMode = debug
    }

    fun setTimeout(milliseconds: Long) = apply {
        timeout = milliseconds
    }

    fun setCustomUserAgent(agent: String) = apply {
        customUserAgent = agent
    }

    fun setEnableWebViewDebug(enable: Boolean) = apply {
        enableWebViewDebug = enable
    }

    fun setEnvironment(env: Environment) = apply {
        environment = env
    }

    fun setH5Domain(domain: String) = apply {
        h5Domain = domain
    }

    fun setApiDomain(domain: String) = apply {
        apiDomain = domain
    }

    fun setAllowedDomains(domains: List<String>) = apply {
        allowedDomains = domains
    }

    fun setEnableParamValidation(enable: Boolean) = apply {
        enableParamValidation = enable
    }

    fun setMaxBridgeParamsSize(maxBytes: Int) = apply {
        maxBridgeParamsSize = maxBytes
    }

    fun setEnableRateLimit(enable: Boolean) = apply {
        enableRateLimit = enable
    }

    fun setSdkVersion(version: String) = apply {
        sdkVersion = version
    }

    fun setEnableBridgeToken(enable: Boolean) = apply {
        enableBridgeToken = enable
    }

    fun setNav(config: NavConfig) = apply {
        nav = config
    }

    fun setNav(block: NavConfig.() -> Unit) = apply {
        nav.apply(block)
    }

    fun setEnableErrorDialog(enable: Boolean) = apply {
        enableErrorDialog = enable
    }

    /**
     * Apply configuration
     * Called after all configuration options are set
     */
    internal fun apply() {
        Logger.setDebugMode(isDebugMode)

        if (enableWebViewDebug) {
            android.webkit.WebView.setWebContentsDebuggingEnabled(true)
        }

        Logger.i("CoconutConfig", "Config applied: env=${environment.displayName}, h5=$effectiveH5Domain, api=$effectiveApiDomain")
    }
}
