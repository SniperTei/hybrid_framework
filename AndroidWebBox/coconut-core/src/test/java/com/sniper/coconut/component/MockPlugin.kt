package com.sniper.coconut.component

import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * In-process CoconutPlugin stub for unit tests. Tracks lifecycle calls and
 * supports configurable handle results / thrown errors.
 *
 * Mirrors iOSWebBox/CoconutSDK/Tests/CoconutSDKTests/MockPlugin.swift.
 */
class MockPlugin(
    override val name: String,
    override val dependencies: List<String> = emptyList(),
    var handleResult: JsonObject = buildJsonObject { put("ok", true) }
) : CoconutPlugin {

    override val version: String = "1.0.0"
    override val description: String = "mock"

    private var isInitializedField = false

    var initCallCount = 0
        private set
    var cleanupCallCount = 0
        private set
    var lastHandledFunction: String? = null
        private set
    var lastHandledParams: JsonObject? = null
        private set

    /** When non-null, [handle] throws this instead of returning [handleResult]. */
    var throwOnHandle: ComponentException? = null

    /** When true, [init] throws (simulates init failure). */
    var failInit: Boolean = false

    override val isInitialized: Boolean
        get() = isInitializedField

    override suspend fun init(context: ComponentContext) {
        initCallCount++
        if (failInit) {
            throw ComponentException(
                code = com.sniper.coconut.bridge.model.ErrorCode.COMPONENT_NOT_INITIALIZED,
                message = "Mock init failure"
            )
        }
        isInitializedField = true
    }

    override suspend fun handle(function: String, params: JsonObject?): JsonElement {
        lastHandledFunction = function
        lastHandledParams = params
        throwOnHandle?.let { throw it }
        return handleResult
    }

    override suspend fun cleanup() {
        cleanupCallCount++
        isInitializedField = false
    }
}
