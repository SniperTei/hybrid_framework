package com.sniper.coconut.bridge

import android.webkit.MimeTypeMap
import com.sniper.coconut.utils.Logger

/**
 * Bridge Security Validator
 *
 * Validates bridge calls for security:
 * - Domain whitelist checking
 * - Parameter size limits
 * - Method name validation
 * - Rate limiting
 */
class BridgeSecurityValidator {

    private val tag = "BridgeSecurity"

    // Domain whitelist: empty means all domains allowed
    private val allowedDomains = mutableSetOf<String>()

    // Rate limiting: tracks call count per method
    private val callCounts = HashMap<String, Int>()
    private var lastResetTime = System.currentTimeMillis()

    // Configurable limits
    var maxParamsSize: Int = DEFAULT_MAX_PARAMS_SIZE
    var rateLimitPerMethod: Int = DEFAULT_RATE_LIMIT
    var rateLimitWindowMs: Long = DEFAULT_RATE_LIMIT_WINDOW_MS

    companion object {
        private const val TAG = "BridgeSecurity"

        const val DEFAULT_MAX_PARAMS_SIZE = 1024 * 1024 // 1MB
        const val DEFAULT_RATE_LIMIT = 100 // calls per window
        const val DEFAULT_RATE_LIMIT_WINDOW_MS = 60_000L // 1 minute
    }

    /**
     * Add allowed domain
     */
    fun addAllowedDomain(domain: String) {
        allowedDomains.add(domain)
        Logger.d(tag, "Added allowed domain: $domain")
    }

    /**
     * Set allowed domains list
     */
    fun setAllowedDomains(domains: List<String>) {
        allowedDomains.clear()
        allowedDomains.addAll(domains)
        Logger.d(tag, "Set allowed domains: $domains")
    }

    /**
     * Check if domain whitelist is configured
     */
    fun hasDomainWhitelist(): Boolean = allowedDomains.isNotEmpty()

    /**
     * Validate a domain against the whitelist
     *
     * @param url The full URL to validate
     * @return SecurityResult
     */
    fun validateDomain(url: String): SecurityResult {
        // No whitelist configured = allow all
        if (allowedDomains.isEmpty()) {
            return SecurityResult.Valid
        }

        val host = extractHost(url)
        if (host.isEmpty()) {
            return SecurityResult.Invalid("Cannot extract host from URL: $url")
        }

        // Check exact match and subdomain match
        val isAllowed = allowedDomains.any { domain ->
            host == domain || host.endsWith(".$domain")
        }

        return if (isAllowed) {
            SecurityResult.Valid
        } else {
            Logger.w(tag, "Domain blocked: $host (allowed: $allowedDomains)")
            SecurityResult.Invalid("Domain not allowed: $host")
        }
    }

    /**
     * Validate parameters size
     */
    fun validateParamsSize(paramsJson: String): SecurityResult {
        if (paramsJson.length > maxParamsSize) {
            Logger.w(tag, "Params too large: ${paramsJson.length} bytes (max: $maxParamsSize)")
            return SecurityResult.Invalid("Params size exceeds limit (${paramsJson.length} > $maxParamsSize)")
        }
        return SecurityResult.Valid
    }

    /**
     * Check rate limit for a method
     */
    fun checkRateLimit(method: String): SecurityResult {
        resetIfNeeded()

        val count = callCounts.getOrDefault(method, 0)
        if (count >= rateLimitPerMethod) {
            Logger.w(tag, "Rate limit exceeded for: $method ($count calls in window)")
            return SecurityResult.Invalid("Rate limit exceeded for method: $method")
        }

        callCounts[method] = count + 1
        return SecurityResult.Valid
    }

    /**
     * Extract host from URL
     */
    private fun extractHost(url: String): String {
        return try {
            val uri = android.net.Uri.parse(url)
            uri.host ?: ""
        } catch (e: Exception) {
            ""
        }
    }

    /**
     * Reset rate limit counters if window has passed
     */
    private fun resetIfNeeded() {
        val now = System.currentTimeMillis()
        if (now - lastResetTime >= rateLimitWindowMs) {
            callCounts.clear()
            lastResetTime = now
        }
    }
}

/**
 * Security validation result
 */
sealed class SecurityResult {
    object Valid : SecurityResult()
    data class Invalid(val reason: String) : SecurityResult()

    val isValid: Boolean get() = this is Valid
    val message: String get() = if (this is Invalid) reason else ""
}
