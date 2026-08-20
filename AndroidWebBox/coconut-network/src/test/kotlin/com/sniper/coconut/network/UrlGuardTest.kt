package com.sniper.coconut.network

import com.sniper.coconut.network.guard.UrlGuard
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class UrlGuardTest {

    @Test
    fun http_withEmptyDomains_allows() {
        val r = UrlGuard.validate("http://anything.example.com/path", emptyList())
        assertTrue(r.allowed)
    }

    @Test
    fun https_exactHostMatch_allows() {
        val r = UrlGuard.validate("https://foo.com/api", listOf("foo.com"))
        assertTrue(r.allowed)
    }

    @Test
    fun subdomainSuffixMatch_allows() {
        val r = UrlGuard.validate("https://api.foo.com/api", listOf("foo.com"))
        assertTrue(r.allowed)
    }

    @Test
    fun subdomainSuffixMatch_multiLevel_allows() {
        val r = UrlGuard.validate("https://a.b.foo.com/api", listOf("foo.com"))
        assertTrue(r.allowed)
    }

    @Test
    fun suffixAttack_isBlocked() {
        val r = UrlGuard.validate("https://api.foo.com.evil.com/api", listOf("foo.com"))
        assertFalse(r.allowed)
        assertTrue(r.reason.contains("allowedDomains"))
    }

    @Test
    fun portIsStrippedFromHost() {
        val r = UrlGuard.validate("https://api.foo.com:8443/api", listOf("foo.com"))
        assertTrue(r.allowed)
    }

    @Test
    fun caseInsensitiveSchemeAndHost() {
        val r = UrlGuard.validate("HTTP://API.FOO.COM/api", listOf("FOO.com"))
        assertTrue(r.allowed)
    }

    @Test
    fun coconutScheme_isBlocked() {
        val r = UrlGuard.validate("coconut://demo/index.html", emptyList())
        assertFalse(r.allowed)
        assertTrue(r.reason.contains("scheme"))
    }

    @Test
    fun fileScheme_isBlocked() {
        val r = UrlGuard.validate("file:///etc/passwd", emptyList())
        assertFalse(r.allowed)
    }

    @Test
    fun javascriptUri_isBlocked() {
        val r = UrlGuard.validate("javascript:alert(1)", emptyList())
        assertFalse(r.allowed)
    }

    @Test
    fun noScheme_isBlocked() {
        val r = UrlGuard.validate("www.foo.com/path", listOf("foo.com"))
        assertFalse(r.allowed)
    }

    @Test
    fun emptyHost_isBlocked() {
        val r = UrlGuard.validate("http:///path", emptyList())
        assertFalse(r.allowed)
    }

    @Test
    fun hostNotInWhitelist_isBlocked() {
        val r = UrlGuard.validate("https://evil.com/api", listOf("foo.com", "bar.com"))
        assertFalse(r.allowed)
        assertTrue(r.reason.contains("evil.com"))
    }
}
