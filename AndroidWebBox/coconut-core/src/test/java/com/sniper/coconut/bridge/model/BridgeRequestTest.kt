package com.sniper.coconut.bridge.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Unit tests for [BridgeRequest] validation helpers.
 *
 * Wire protocol v3.0.0: `component` and `function` are separate top-level
 * fields (no joined `method` field on the wire). The `method` property on
 * the data class is computed locally for logging/metrics only.
 */
class BridgeRequestTest {

    // ---- isValidName (used for both component and function) ----

    @Test
    fun isValidName_acceptsSimpleIdentifier() {
        assertTrue(BridgeRequest.isValidName("device"))
        assertTrue(BridgeRequest.isValidName("getInfo"))
    }

    @Test
    fun isValidName_acceptsUnderscoreAndDigitsAfterFirstChar() {
        assertTrue(BridgeRequest.isValidName("device_2"))
        assertTrue(BridgeRequest.isValidName("get_info_3"))
    }

    @Test
    fun isValidName_rejectsEmpty() {
        assertFalse(BridgeRequest.isValidName(""))
    }

    @Test
    fun isValidName_rejectsStartsWithDigit() {
        assertFalse(BridgeRequest.isValidName("1device"))
    }

    @Test
    fun isValidName_rejectsSpecialChars() {
        assertFalse(BridgeRequest.isValidName("dev-ice"))
        assertFalse(BridgeRequest.isValidName("storage.item"))  // dot no longer allowed
    }

    // ---- method convenience property ----

    @Test
    fun method_joinsComponentAndFunction() {
        val request = BridgeRequest(component = "storage", function = "setItem", id = "req-1")
        assertEquals("storage.setItem", request.method)
    }

    // ---- validate ----

    @Test
    fun validate_successOnValidRequest() {
        val request = BridgeRequest(component = "device", function = "getInfo", id = "req-1")
        val result = request.validate()
        assertTrue(result.isValid)
        assertEquals("", result.message)
    }

    @Test
    fun validate_failsOnBlankId() {
        val request = BridgeRequest(component = "device", function = "getInfo", id = "")
        val result = request.validate()
        assertFalse(result.isValid)
        assertTrue(result.message.contains("ID"))
    }

    @Test
    fun validate_failsOnInvalidComponent() {
        val request = BridgeRequest(component = "bad.component", function = "getInfo", id = "req-1")
        val result = request.validate()
        assertFalse(result.isValid)
        assertTrue(result.message.contains("component"))
    }

    @Test
    fun validate_failsOnInvalidFunction() {
        val request = BridgeRequest(component = "device", function = "bad function", id = "req-1")
        val result = request.validate()
        assertFalse(result.isValid)
        assertTrue(result.message.contains("function"))
    }
}
