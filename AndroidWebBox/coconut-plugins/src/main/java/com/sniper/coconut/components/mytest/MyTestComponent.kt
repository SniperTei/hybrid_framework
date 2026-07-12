package com.sniper.coconut.components.mytest

import com.sniper.coconut.component.BaseComponent
import com.sniper.coconut.component.ComponentMetadata
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * MyTest Component
 *
 * A minimal scaffold component for development/debugging.
 * Useful for verifying that the Bridge → Component routing works end-to-end,
 * and as a copy-paste starting point when adding a new real component.
 *
 * Functions:
 *   - ping: {} -> { pong: true, timestamp }
 *   - echo: { message } -> { message }
 *   - add:  { a, b } -> { sum }
 */
@ComponentMetadata(
    name = "mytest",
    version = "1.0.0",
    description = "Test scaffold component for development"
)
class MyTestComponent : BaseComponent() {

    override val name = "mytest"
    override val version = "1.0.0"
    override val description = "Test scaffold component for development"

    override suspend fun handle(function: String, params: JsonObject?): JsonElement {
        return when (function) {
            "ping" -> ping()
            "echo" -> echo(params)
            "add" -> add(params)
            else -> functionNotSupportedError(function)
        }
    }

    private fun ping(): JsonElement {
        return buildJsonObject {
            put("pong", JsonPrimitive(true))
            put("timestamp", JsonPrimitive(System.currentTimeMillis()))
        }.let { success(it) }
    }

    private fun echo(params: JsonObject?): JsonElement {
        val message = getParam(params, "message")
        if (message.isEmpty()) {
            return paramValidationError("Parameter 'message' is required")
        }
        return buildJsonObject {
            put("message", JsonPrimitive(message))
        }.let { success(it) }
    }

    private fun add(params: JsonObject?): JsonElement {
        val a = getIntParam(params, "a", 0)
        val b = getIntParam(params, "b", 0)
        return buildJsonObject {
            put("sum", JsonPrimitive(a + b))
        }.let { success(it) }
    }
}
