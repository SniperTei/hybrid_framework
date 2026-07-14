package com.sniper.coconut.component

import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

/**
 * Unit tests for [BaseComponent] parameter helpers.
 *
 * Android-only — the iOS BaseComponent does not embed these helpers.
 */
class BaseComponentTest {

    /** Concrete subclass exposing the protected helpers for testing. */
    private class TestComponent : BaseComponent() {
        override val name = "test"
        override val version = "1.0.0"
        override val description = "test component"

        override suspend fun handle(function: String, params: kotlinx.serialization.json.JsonObject?): kotlinx.serialization.json.JsonElement {
            // Unused; tests call the helpers directly below.
            return JsonPrimitive("ok")
        }

        fun exposedGetParam(params: kotlinx.serialization.json.JsonObject?, key: String, default: String = "") =
            getParam(params, key, default)

        fun exposedGetIntParam(params: kotlinx.serialization.json.JsonObject?, key: String, default: Int = 0) =
            getIntParam(params, key, default)

        fun exposedGetBoolParam(params: kotlinx.serialization.json.JsonObject?, key: String, default: Boolean = false) =
            getBoolParam(params, key, default)
    }

    private val component = TestComponent()

    // ---- getParam (string) ----

    @Test
    fun getParam_returnsStringPrimitive() {
        val params = buildJsonObject { put("name", "alice") }
        assertEquals("alice", component.exposedGetParam(params, "name"))
    }

    @Test
    fun getParam_returnsDefaultWhenMissing() {
        val params = buildJsonObject { }
        assertEquals("fallback", component.exposedGetParam(params, "missing", "fallback"))
        assertEquals("", component.exposedGetParam(null, "missing"))
    }

    // ---- getIntParam ----

    @Test
    fun getIntParam_parsesNumber() {
        val params = buildJsonObject { put("count", 42) }
        assertEquals(42, component.exposedGetIntParam(params, "count"))
    }

    @Test
    fun getIntParam_returnsDefaultOnInvalidNumber() {
        val params = buildJsonObject { put("count", "abc") }
        assertEquals(-1, component.exposedGetIntParam(params, "count", -1))
    }

    // ---- getBoolParam ----

    @Test
    fun getBoolParam_parsesTrueFalseStrict() {
        val trues = buildJsonObject { put("flag", "true") }
        val falses = buildJsonObject { put("flag", "false") }
        assertEquals(true, component.exposedGetBoolParam(trues, "flag"))
        assertEquals(false, component.exposedGetBoolParam(falses, "flag"))
    }

    @Test
    fun getBoolParam_returnsDefaultOnInvalidValue() {
        val params = buildJsonObject { put("flag", "yes") }  // not strict true/false
        assertEquals(true, component.exposedGetBoolParam(params, "flag", true))
    }
}
