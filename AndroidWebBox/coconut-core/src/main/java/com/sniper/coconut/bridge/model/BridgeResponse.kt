package com.sniper.coconut.bridge.model

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull

/**
 * Bridge Response Model (Flattened)
 *
 * Flattened response format:
 * {
 *   "id": "request-id",
 *   "code": "000000",
 *   "message": "success",
 *   "result": { ... },
 *   "streaming": true   // optional; present = more responses coming, callback kept
 * }
 *
 * For streaming use cases (queue progress, download progress, etc.), native
 * sends multiple responses with the same id. All but the final response
 * include `"streaming": true`. The final response omits the field (or sets
 * it to false) — coconut.js then releases the callback.
 */
@Serializable
data class BridgeResponse(
    val id: String,
    val code: String = ErrorCode.SUCCESS,
    val message: String = "success",
    val result: JsonElement? = null,
    val streaming: Boolean? = null
) {
    companion object {
        /**
         * Create success response (one-shot; callback released after this).
         */
        fun success(id: String, result: JsonElement? = null): BridgeResponse {
            return BridgeResponse(
                id = id,
                code = ErrorCode.SUCCESS,
                message = "success",
                result = result ?: JsonNull
            )
        }

        /**
         * Create a streaming response. coconut.js fires the callback but
         * keeps it registered for subsequent responses with the same id
         * (and resets the timeout timer). Send a final non-streaming
         * response (omit `streaming`) to release the callback.
         */
        fun streaming(id: String, result: JsonElement? = null): BridgeResponse {
            return BridgeResponse(
                id = id,
                code = ErrorCode.SUCCESS,
                message = "success",
                result = result ?: JsonNull,
                streaming = true
            )
        }

        /**
         * Create error response (always releases the callback).
         */
        fun error(id: String, code: String, message: String): BridgeResponse {
            return BridgeResponse(
                id = id,
                code = code,
                message = message,
                result = null
            )
        }

        /**
         * Parse error (invalid JSON)
         */
        fun parseError(id: String, message: String = "Parse error"): BridgeResponse {
            return error(id, ErrorCode.PARSE_ERROR, message)
        }

        /**
         * Invalid request
         */
        fun invalidRequest(id: String, message: String = "Invalid request"): BridgeResponse {
            return error(id, ErrorCode.INVALID_REQUEST, message)
        }

        /**
         * Method not found
         */
        fun methodNotFound(id: String, method: String): BridgeResponse {
            return error(id, ErrorCode.METHOD_NOT_FOUND, "Method not found: $method")
        }

        /**
         * Invalid params
         */
        fun invalidParams(id: String, message: String = "Invalid params"): BridgeResponse {
            return error(id, ErrorCode.INVALID_PARAMS, message)
        }

        /**
         * Internal error
         */
        fun internalError(id: String, message: String = "Internal error"): BridgeResponse {
            return error(id, ErrorCode.INTERNAL_ERROR, message)
        }
    }

    /**
     * Check if response is successful
     */
    val isSuccess: Boolean
        get() = code == ErrorCode.SUCCESS

    /**
     * Check if response is error
     */
    val isError: Boolean
        get() = code != ErrorCode.SUCCESS
}

/**
 * Standard Error Codes (6-digit strings)
 *
 * | Range      | Category     |
 * |------------|-------------|
 * | 000000     | Success     |
 * | 100001-100005 | Standard errors |
 * | 200001-200009 | Business errors |
 * | 300001-300004 | Security errors |
 */
object ErrorCode {
    const val SUCCESS = "000000"

    // Standard errors (100001-100005)
    const val PARSE_ERROR = "100001"
    const val INVALID_REQUEST = "100002"
    const val METHOD_NOT_FOUND = "100003"
    const val INVALID_PARAMS = "100004"
    const val INTERNAL_ERROR = "100005"

    // Business errors (200001-200009)
    const val UNKNOWN_COMPONENT = "200001"
    const val UNKNOWN_FUNCTION = "200002"
    const val PERMISSION_DENIED = "200003"
    const val TIMEOUT = "200004"
    const val CANCELLED = "200005"
    const val DOMAIN_NOT_ALLOWED = "200006"
    const val PARAM_VALIDATION_FAILED = "200007"
    const val COMPONENT_NOT_INITIALIZED = "200008"
    const val RATE_LIMIT_EXCEEDED = "200009"

    // Security errors (300001-300004)
    const val BRIDGE_TOKEN_INVALID = "300004"

    // Error code descriptions
    fun getDescription(code: String): String = when (code) {
        PARSE_ERROR -> "Parse error"
        INVALID_REQUEST -> "Invalid request"
        METHOD_NOT_FOUND -> "Method not found"
        INVALID_PARAMS -> "Invalid params"
        INTERNAL_ERROR -> "Internal error"
        UNKNOWN_COMPONENT -> "Unknown component"
        UNKNOWN_FUNCTION -> "Unknown function"
        PERMISSION_DENIED -> "Permission denied"
        TIMEOUT -> "Request timeout"
        CANCELLED -> "Request cancelled"
        DOMAIN_NOT_ALLOWED -> "Domain not allowed"
        PARAM_VALIDATION_FAILED -> "Parameter validation failed"
        COMPONENT_NOT_INITIALIZED -> "Component not initialized"
        RATE_LIMIT_EXCEEDED -> "Rate limit exceeded"
        BRIDGE_TOKEN_INVALID -> "Bridge token invalid"
        else -> "Unknown error"
    }
}
