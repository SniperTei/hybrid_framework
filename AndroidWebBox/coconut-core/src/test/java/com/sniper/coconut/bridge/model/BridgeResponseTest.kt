package com.sniper.coconut.bridge.model

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Unit tests for [BridgeResponse] factory methods and serialization.
 * Mirrors iOS BridgeResponseTests.
 */
class BridgeResponseTest {

    // ---- success factory ----

    @Test
    fun success_hasSuccessCodeAndMessage() {
        val response = BridgeResponse.success(id = "req-1")
        assertEquals(ErrorCode.SUCCESS, response.code)
        assertEquals("success", response.message)
        assertEquals("req-1", response.id)
        assertEquals(BridgeResponse.JSONRPC_VERSION, response.jsonrpc)
    }

    @Test
    fun success_carriesResult() {
        val payload: JsonObject = buildJsonObject { put("value", 42) }
        val response = BridgeResponse.success(id = "req-1", result = payload)
        assertEquals(payload, response.result)
    }

    @Test
    fun success_defaultsResultToJsonNull() {
        val response = BridgeResponse.success(id = "req-1")
        assertEquals(kotlinx.serialization.json.JsonNull, response.result)
    }

    // ---- error factories ----

    @Test
    fun error_passesThroughFields() {
        val response = BridgeResponse.error(id = "req-1", code = "999999", message = "boom")
        assertEquals("999999", response.code)
        assertEquals("boom", response.message)
        assertNull(response.result)
    }

    @Test
    fun parseError_usesParseErrorCode() {
        val response = BridgeResponse.parseError(id = "req-1")
        assertEquals(ErrorCode.PARSE_ERROR, response.code)
    }

    @Test
    fun invalidRequest_usesInvalidRequestCode() {
        val response = BridgeResponse.invalidRequest(id = "req-1")
        assertEquals(ErrorCode.INVALID_REQUEST, response.code)
    }

    @Test
    fun methodNotFound_includesMethodInMessage() {
        val response = BridgeResponse.methodNotFound(id = "req-1", method = "device.unknown")
        assertEquals(ErrorCode.METHOD_NOT_FOUND, response.code)
        assertTrue(response.message.contains("device.unknown"))
    }

    @Test
    fun invalidParams_usesInvalidParamsCode() {
        val response = BridgeResponse.invalidParams(id = "req-1")
        assertEquals(ErrorCode.INVALID_PARAMS, response.code)
    }

    @Test
    fun internalError_usesInternalErrorCode() {
        val response = BridgeResponse.internalError(id = "req-1")
        assertEquals(ErrorCode.INTERNAL_ERROR, response.code)
    }

    // ---- isSuccess / isError ----

    @Test
    fun isSuccess_trueForSuccessCode() {
        assertTrue(BridgeResponse.success(id = "x").isSuccess)
        assertFalse(BridgeResponse.success(id = "x").isError)
    }

    @Test
    fun isError_trueForNonSuccessCode() {
        val err = BridgeResponse.error(id = "x", code = ErrorCode.INTERNAL_ERROR, message = "m")
        assertTrue(err.isError)
        assertFalse(err.isSuccess)
    }

    // ---- serialization round-trip ----

    @Test
    fun serialize_roundTripsCoreFields() {
        val payload: JsonObject = buildJsonObject { put("value", 42) }
        val original = BridgeResponse.success(id = "rt-1", result = payload)

        val json = Json.encodeToString(BridgeResponse.serializer(), original)
        val decoded = Json.decodeFromString(BridgeResponse.serializer(), json)

        assertEquals(original.id, decoded.id)
        assertEquals(original.code, decoded.code)
        assertEquals(original.message, decoded.message)
        assertEquals(original.jsonrpc, decoded.jsonrpc)
        // result content equality
        val originalValue = (original.result as? JsonObject)?.get("value") as? JsonPrimitive
        val decodedValue = (decoded.result as? JsonObject)?.get("value") as? JsonPrimitive
        assertEquals(originalValue?.content, decodedValue?.content)
    }
}
