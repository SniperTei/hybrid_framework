package com.sniper.coconut.bridge.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Unit tests for [BridgeRequest] validation helpers.
 *
 * Mirrors the Android-only validation logic embedded in the data class
 * (no iOS counterpart — iOS validates in the dispatcher).
 */
class BridgeRequestTest {

    // ---- isValidMethod ----

    @Test
    fun isValidMethod_acceptsComponentDotFunction() {
        assertTrue(BridgeRequest.isValidMethod("device.getInfo"))
    }

    @Test
    fun isValidMethod_acceptsUnderscoreAndDigitsAfterFirstChar() {
        assertTrue(BridgeRequest.isValidMethod("device_2.get_info_3"))
    }

    @Test
    fun isValidMethod_rejectsNoDot() {
        assertFalse(BridgeRequest.isValidMethod("noDot"))
    }

    @Test
    fun isValidMethod_rejectsStartsWithDigit() {
        assertFalse(BridgeRequest.isValidMethod("1device.getInfo"))
    }

    @Test
    fun isValidMethod_rejectsSpecialChars() {
        assertFalse(BridgeRequest.isValidMethod("dev-ice.getInfo"))
    }

    // ---- extractComponent / extractFunction ----

    @Test
    fun extractComponent_returnsBeforeDot() {
        assertEquals("device", BridgeRequest.extractComponent("device.getInfo"))
    }

    @Test
    fun extractFunction_returnsAfterDot() {
        assertEquals("getInfo", BridgeRequest.extractFunction("device.getInfo"))
    }

    // ---- validate ----

    @Test
    fun validate_successOnValidRequest() {
        val request = BridgeRequest(method = "device.getInfo", id = "req-1")
        val result = request.validate()
        assertTrue(result.isValid)
        assertEquals("", result.message)
    }

    @Test
    fun validate_failsOnBlankId() {
        val request = BridgeRequest(method = "device.getInfo", id = "")
        val result = request.validate()
        assertFalse(result.isValid)
        assertTrue(result.message.contains("ID"))
    }

    @Test
    fun validate_failsOnInvalidMethod() {
        val request = BridgeRequest(method = "bad", id = "req-1")
        val result = request.validate()
        assertFalse(result.isValid)
        assertTrue(result.message.contains("method"))
    }

    @Test
    fun validate_failsOnWrongJsonrpcVersion() {
        val request = BridgeRequest(jsonrpc = "1.0", method = "device.getInfo", id = "req-1")
        val result = request.validate()
        assertFalse(result.isValid)
        assertTrue(result.message.contains("JSON-RPC"))
    }
}
