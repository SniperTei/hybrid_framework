package com.sniper.coconut.bridge

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * Unit tests for [BridgeSecurityValidator].
 *
 * Coverage gap motivation: this class was previously 0% covered in JVM unit tests
 * because [android.net.Uri.parse] is stubbed on the JVM host (returns null). After
 * refactoring [BridgeSecurityValidator.extractHost] to use [java.net.URI.create],
 * the validator is now pure-JVM testable.
 *
 * Mirrors the spirit of the iOS BridgeSecurityValidatorTests.
 */
class BridgeSecurityValidatorTest {

    private lateinit var validator: BridgeSecurityValidator

    @Before
    fun setUp() {
        validator = BridgeSecurityValidator()
    }

    // -------------------- extractHost (via validateDomain) --------------------

    @Test
    fun extractHost_httpsUrl_returnsHost() {
        validator.setAllowedDomains(listOf("example.com"))

        val result = validator.validateDomain("https://example.com/path/to/page")

        assertEquals(SecurityResult.Valid, result)
    }

    @Test
    fun extractHost_withPort_stripsPort() {
        validator.setAllowedDomains(listOf("example.com"))

        // URI.host strips port automatically
        val result = validator.validateDomain("https://example.com:8080/api")

        assertEquals(SecurityResult.Valid, result)
    }

    @Test
    fun extractHost_withPath_stripsPath() {
        validator.setAllowedDomains(listOf("example.com"))

        val result = validator.validateDomain("https://example.com/deep/nested/path?q=1")

        assertEquals(SecurityResult.Valid, result)
    }

    @Test
    fun extractHost_invalidUrl_returnsEmpty() {
        validator.setAllowedDomains(listOf("example.com"))

        // No scheme/host → URI.host is null → extractHost returns "" → Invalid
        val result = validator.validateDomain("not a url")

        assertFalse(result.isValid)
        assertTrue(
            "Expected 'Cannot extract host' reason, got: ${result.message}",
            result.message.contains("Cannot extract host")
        )
    }

    @Test
    fun extractHost_emptyString_returnsEmpty() {
        validator.setAllowedDomains(listOf("example.com"))

        val result = validator.validateDomain("")

        assertFalse(result.isValid)
        assertTrue(result.message.contains("Cannot extract host"))
    }

    // -------------------- validateDomain --------------------

    @Test
    fun validateDomain_emptyWhitelist_isValid() {
        // Design intent: no whitelist configured = allow all
        // (BridgeSecurityValidator.hasDomainWhitelist() is false)
        val result = validator.validateDomain("https://anywhere.example/path")

        assertEquals(SecurityResult.Valid, result)
    }

    @Test
    fun validateDomain_inWhitelist_isValid() {
        validator.setAllowedDomains(listOf("example.com", "api.test.com"))

        assertTrue(validator.validateDomain("https://example.com/").isValid)
        assertTrue(validator.validateDomain("https://api.test.com/").isValid)
    }

    @Test
    fun validateDomain_subdomainOfWhitelisted_isValid() {
        validator.setAllowedDomains(listOf("example.com"))

        // Subdomain match: host ends with ".example.com"
        assertTrue(validator.validateDomain("https://sub.example.com/").isValid)
        assertTrue(validator.validateDomain("https://deep.sub.example.com/").isValid)
    }

    @Test
    fun validateDomain_notInWhitelist_isInvalid() {
        validator.setAllowedDomains(listOf("example.com"))

        val result = validator.validateDomain("https://evil.example.org/")

        assertFalse(result.isValid)
        assertTrue(result.message.contains("Domain not allowed"))
    }

    @Test
    fun validateDomain_almostMatchingDomain_isInvalid() {
        // Regression: "evil.example.org" must NOT match "example.com"
        // and "example.com.evil.org" must NOT match either (prefix-only attack)
        validator.setAllowedDomains(listOf("example.com"))

        assertFalse(validator.validateDomain("https://example.com.evil.org/").isValid)
        assertFalse(validator.validateDomain("https://notexample.com/").isValid)
    }

    @Test
    fun validateDomain_localScheme_exemptFromWhitelist() {
        // Offline-package / bundled-content schemes carry no host
        validator.setAllowedDomains(listOf("example.com"))

        assertTrue(validator.validateDomain("coconut://demo/index.html").isValid)
        assertTrue(validator.validateDomain("file:///android_asset/coconut-web/demo/index.html").isValid)
    }

    // -------------------- checkRateLimit --------------------

    @Test
    fun checkRateLimit_underLimit_isValid() {
        validator.rateLimitPerMethod = 3

        repeat(3) {
            assertEquals(SecurityResult.Valid, validator.checkRateLimit("storage.getItem"))
        }
    }

    @Test
    fun checkRateLimit_overLimit_isInvalid() {
        validator.rateLimitPerMethod = 3

        repeat(3) {
            validator.checkRateLimit("storage.getItem")
        }
        // 4th call should exceed the limit
        val result = validator.checkRateLimit("storage.getItem")

        assertFalse(result.isValid)
        assertTrue(result.message.contains("Rate limit exceeded"))
    }

    @Test
    fun checkRateLimit_differentMethodsAreIndependent() {
        validator.rateLimitPerMethod = 2

        repeat(2) { validator.checkRateLimit("storage.getItem") }
        // storage.getItem is exhausted, but device.getInfo should still pass
        assertEquals(SecurityResult.Valid, validator.checkRateLimit("device.getInfo"))
    }

    // -------------------- validateParamsSize --------------------

    @Test
    fun validateParamsSize_underLimit_isValid() {
        validator.maxParamsSize = 10

        val result = validator.validateParamsSize("short")

        assertEquals(SecurityResult.Valid, result)
    }

    @Test
    fun validateParamsSize_overLimit_isInvalid() {
        validator.maxParamsSize = 10

        val big = "x".repeat(11)
        val result = validator.validateParamsSize(big)

        assertFalse(result.isValid)
        assertTrue(result.message.contains("Params size exceeds limit"))
    }
}
