package com.sniper.coconut.bridge

import android.webkit.WebView
import com.sniper.coconut.bridge.model.BridgeRequest
import com.sniper.coconut.bridge.model.BridgeResponse
import com.sniper.coconut.bridge.model.ErrorCode
import com.sniper.coconut.component.CoconutPlugin
import com.sniper.coconut.component.ComponentManager
import com.sniper.coconut.utils.Logger
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.encodeToJsonElement

/**
 * Coconut Bridge Implementation
 *
 * Implements CoconutBridge interface with JSON-RPC 2.0 protocol
 */
class CoconutBridgeImpl(
    private val componentManager: ComponentManager
) : CoconutBridge {

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    override fun handleCall(webView: WebView, jsonData: String): String {
        return try {
            Logger.d("CoconutBridgeImpl", "Received call: $jsonData")

            // Parse request
            val request = try {
                json.decodeFromString<BridgeRequest>(jsonData)
            } catch (e: Exception) {
                Logger.e("CoconutBridgeImpl", "Failed to parse request", e)
                return json.encodeToString(
                    BridgeResponse.serializer(),
                    BridgeResponse.parseError("", e.message ?: "Parse error")
                )
            }

            // Validate request
            val validation = request.validate()
            if (!validation.isValid) {
                Logger.e("CoconutBridgeImpl", "Invalid request: ${validation.message}")
                return json.encodeToString(
                    BridgeResponse.serializer(),
                    BridgeResponse.invalidRequest(request.id, validation.message)
                )
            }

            // Handle request synchronously
            val result = runBlocking(Dispatchers.Main) {
                handleRequest(request)
            }

            // Return success response
            json.encodeToString(
                BridgeResponse.serializer(),
                BridgeResponse.success(request.id, result)
            )

        } catch (e: Exception) {
            Logger.e("CoconutBridgeImpl", "Error handling call", e)
            json.encodeToString(
                BridgeResponse.serializer(),
                BridgeResponse.internalError("", e.message ?: "Internal error")
            )
        }
    }

    private suspend fun handleRequest(request: BridgeRequest): JsonElement {
        // Get component for module
        val component = componentManager.getComponent(request.componentName)
        if (component == null) {
            throw ComponentNotFoundException("Component not found: ${request.componentName}")
        }

        // Execute component function
        return component.handle(request.functionName, request.params)
    }

    private fun sendSuccess(webView: WebView, requestId: String, result: JsonElement?) {
        val response = BridgeResponse.success(requestId, result)
        val responseJson = json.encodeToString(BridgeResponse.serializer(), response)
        callJS(webView, "__coconutCallback", mapOf("response" to responseJson))
    }

    private fun sendError(webView: WebView, requestId: String, code: Int, message: String) {
        val response = BridgeResponse.error(requestId, code, message)
        val responseJson = json.encodeToString(BridgeResponse.serializer(), response)
        callJS(webView, "__coconutCallback", mapOf("response" to responseJson))
    }

    override fun callJS(webView: WebView, functionName: String, params: Map<String, Any?>) {
        val paramsJson = try {
            json.encodeToJsonElement(params)
        } catch (e: Exception) {
            Logger.e("CoconutBridgeImpl", "Failed to encode params", e)
            JsonNull
        }

        val script = buildString {
            append("if (typeof $functionName === 'function') {")
            append("$functionName(")
            append(paramsJson.toString())
            append(");")
            append("}")
        }

        webView.post {
            webView.evaluateJavascript(script, null)
        }
    }

    override fun cleanup() {
        // Cleanup will be handled by manager
    }
}

/**
 * Component not found exception
 */
class ComponentNotFoundException(message: String) : Exception(message)
