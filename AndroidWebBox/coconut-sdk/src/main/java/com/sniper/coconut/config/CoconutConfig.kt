package com.sniper.coconut.config

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

    fun setAutoRegisterComponents(enable: Boolean) = apply {
        autoRegisterComponents = enable
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
