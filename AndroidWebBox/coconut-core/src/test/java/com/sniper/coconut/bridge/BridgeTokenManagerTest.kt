package com.sniper.coconut.bridge

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * Unit tests for [BridgeTokenManager].
 * Mirrors iOS BridgeTokenManagerTests.
 */
class BridgeTokenManagerTest {

    @Before
    fun setUp() {
        BridgeTokenManager.enabled = true
        BridgeTokenManager.reset()
    }

    @After
    fun tearDown() {
        BridgeTokenManager.reset()
        BridgeTokenManager.enabled = true
    }

    @Test
    fun initialToken_isEmpty_andEmptyTokenValidatesAnything() {
        assertEquals("", BridgeTokenManager.getToken())
        // When token has never been generated, validation is permissive (allows initialization).
        assertTrue(BridgeTokenManager.validateToken("anything"))
        assertTrue(BridgeTokenManager.validateToken(""))
    }

    @Test
    fun generateToken_returnsNonEmpty() {
        val token = BridgeTokenManager.generateToken()
        assertTrue(token.isNotEmpty())
        assertEquals(token, BridgeTokenManager.getToken())
    }

    @Test
    fun generateToken_producesDifferentValues() {
        val a = BridgeTokenManager.generateToken()
        val b = BridgeTokenManager.generateToken()
        assertNotEquals(a, b)
    }

    @Test
    fun validateToken_correctTokenPasses() {
        val token = BridgeTokenManager.generateToken()
        assertTrue(BridgeTokenManager.validateToken(token))
    }

    @Test
    fun validateToken_wrongTokenFails() {
        BridgeTokenManager.generateToken()
        assertFalse(BridgeTokenManager.validateToken("wrong-token"))
        assertFalse(BridgeTokenManager.validateToken(""))
    }

    @Test
    fun disabled_allowsAnyToken() {
        BridgeTokenManager.generateToken()
        BridgeTokenManager.enabled = false
        assertTrue(BridgeTokenManager.validateToken("anything"))
        assertTrue(BridgeTokenManager.validateToken(""))
    }

    @Test
    fun reset_clearsToken() {
        BridgeTokenManager.generateToken()
        BridgeTokenManager.reset()
        assertEquals("", BridgeTokenManager.getToken())
        // After reset the manager behaves as un-initialized → permissive again.
        assertTrue(BridgeTokenManager.validateToken("anything"))
    }
}
