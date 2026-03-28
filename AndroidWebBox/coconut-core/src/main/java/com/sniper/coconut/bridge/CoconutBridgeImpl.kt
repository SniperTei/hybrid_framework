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
 * Implements CoconutBridge interface with JSON-RPC 2.0 protocol.
 * Includes security validation, performance logging, and error handling.
 */
class CoconutBridgeImpl(
    private val componentManager: ComponentManager
) : CoconutBridge {

    private val tag = "CoconutBridgeImpl"

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    val securityValidator = BridgeSecurityValidator()

    override fun handleCall(webView: WebView, jsonData: String, currentUrl: String): String {
        return try {
            Logger.d(tag, "Received call: $jsonData")

            // 1. Parse request
            val request = try {
                json.decodeFromString<BridgeRequest>(jsonData)
            } catch (e: Exception) {
                Logger.e(tag, "Failed to parse request", e)
                return json.encodeToString(
                    BridgeResponse.serializer(),
                    BridgeResponse.parseError("", e.message ?: "Parse error")
                )
            }

            // 2. Validate request format
            val validation = request.validate()
            if (!validation.isValid) {
                Logger.logBridgeCallValidation(request.method, request.id, validation.message)
                return json.encodeToString(
                    BridgeResponse.serializer(),
                    BridgeResponse.invalidRequest(request.id, validation.message)
                )
            }

            Logger.logBridgeCallStart(request.method, request.id)

            // 3. Domain whitelist check (using cached URL, no WebView access)
            val domainResult = securityValidator.validateDomain(currentUrl)
            if (!domainResult.isValid) {
                Logger.logBridgeCallError(request.method, request.id, ErrorCode.DOMAIN_NOT_ALLOWED, domainResult.message)
                return json.encodeToString(
                    BridgeResponse.serializer(),
                    BridgeResponse.error(request.id, ErrorCode.DOMAIN_NOT_ALLOWED, domainResult.message)
                )
            }

            // 4. Rate limit check
            val rateLimitResult = securityValidator.checkRateLimit(request.method)
            if (!rateLimitResult.isValid) {
                Logger.logBridgeCallError(request.method, request.id, ErrorCode.RATE_LIMIT_EXCEEDED, rateLimitResult.message)
                return json.encodeToString(
                    BridgeResponse.serializer(),
                    BridgeResponse.error(request.id, ErrorCode.RATE_LIMIT_EXCEEDED, rateLimitResult.message)
                )
            }

            // 5. Params size check
            val paramsSizeResult = securityValidator.validateParamsSize(jsonData)
            if (!paramsSizeResult.isValid) {
                Logger.logBridgeCallError(request.method, request.id, ErrorCode.PARAM_VALIDATION_FAILED, paramsSizeResult.message)
                return json.encodeToString(
                    BridgeResponse.serializer(),
                    BridgeResponse.error(request.id, ErrorCode.PARAM_VALIDATION_FAILED, paramsSizeResult.message)
                )
            }

            // 6. Execute request with performance tracking
            var bridgeSuccess = true
            var durationMs = 0L
            val result: JsonElement
            val startMs = System.currentTimeMillis()
            try {
                result = runBlocking(Dispatchers.Main) {
                    handleRequest(request)
                }
                durationMs = System.currentTimeMillis() - startMs
            } catch (e: Exception) {
                durationMs = System.currentTimeMillis() - startMs
                bridgeSuccess = false
                BridgePerformance.record(request.method, durationMs, false)
                throw e
            }

            // Record performance metrics
            BridgePerformance.record(request.method, durationMs, bridgeSuccess)

            // 7. Return success
            Logger.logBridgeCallSuccess(request.method, request.id)
            json.encodeToString(
                BridgeResponse.serializer(),
                BridgeResponse.success(request.id, result)
            )

        } catch (e: ComponentNotFoundException) {
            val requestMethod = extractMethodFromJson(jsonData)
            val requestId = extractIdFromJson(jsonData)
            Logger.logBridgeCallError(requestMethod, requestId, ErrorCode.UNKNOWN_COMPONENT, e.message ?: "Component not found")
            json.encodeToString(
                BridgeResponse.serializer(),
                BridgeResponse.error(requestId, ErrorCode.UNKNOWN_COMPONENT, e.message ?: "Component not found")
            )
        } catch (e: Exception) {
            Logger.e(tag, "Error handling call", e)
            val requestId = extractIdFromJson(jsonData)
            json.encodeToString(
                BridgeResponse.serializer(),
                BridgeResponse.internalError(requestId, e.message ?: "Internal error")
            )
        }
    }

    private suspend fun handleRequest(request: BridgeRequest): JsonElement {
        // Get component
        val component = componentManager.getComponent(request.componentName)
            ?: throw ComponentNotFoundException("Component not found: ${request.componentName}")

        // Check component is initialized
        if (!component.isInitialized) {
            throw ComponentNotInitializedException("Component not initialized: ${request.componentName}")
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
            Logger.e(tag, "Failed to encode params", e)
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

    // ---- JSON extraction helpers for error cases ----

    private fun extractMethodFromJson(jsonData: String): String {
        return try {
            jsonData.substringAfter("\"method\":\"").substringBefore("\"")
        } catch (e: Exception) {
            "unknown"
        }
    }

    private fun extractIdFromJson(jsonData: String): String {
        return try {
            jsonData.substringAfter("\"id\":\"").substringBefore("\"")
        } catch (e: Exception) {
            ""
        }
    }
}

/**
 * Component not found exception
 */
class ComponentNotFoundException(message: String) : Exception(message)

/**
 * Component not initialized exception
 */
class ComponentNotInitializedException(message: String) : Exception(message)
