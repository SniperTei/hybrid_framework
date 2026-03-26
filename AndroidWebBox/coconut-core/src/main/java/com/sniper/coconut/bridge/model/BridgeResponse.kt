package com.sniper.coconut.bridge.model

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull

/**
 * JSON-RPC 2.0 Response Model
 *
 * Standard JSON-RPC 2.0 response format:
 * {
 *   "jsonrpc": "2.0",
 *   "result": { ... },
 *   "error": null,
 *   "id": "request-id"
 * }
 */
@Serializable
data class BridgeResponse(
    val jsonrpc: String = "2.0",
    val result: JsonElement? = null,
    val error: BridgeError? = null,
    val id: String
) {
    companion object {
        const val JSONRPC_VERSION = "2.0"

        /**
         * Create success response
         */
        fun success(id: String, result: JsonElement? = null): BridgeResponse {
            return BridgeResponse(
                jsonrpc = JSONRPC_VERSION,
                result = result ?: JsonNull,
                error = null,
                id = id
            )
        }

        /**
         * Create error response
         */
        fun error(id: String, code: Int, message: String, data: JsonElement? = null): BridgeResponse {
            return BridgeResponse(
                jsonrpc = JSONRPC_VERSION,
                result = null,
                error = BridgeError(code, message, data),
                id = id
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
        get() = error == null

    /**
     * Check if response is error
     */
    val isError: Boolean
        get() = error != null
}

/**
 * JSON-RPC 2.0 Error Object
 */
@Serializable
data class BridgeError(
    val code: Int,
    val message: String,
    val data: JsonElement? = null
)

/**
 * Standard JSON-RPC 2.0 Error Codes
 */
object ErrorCode {
    const val PARSE_ERROR = -32700
    const val INVALID_REQUEST = -32600
    const val METHOD_NOT_FOUND = -32601
    const val INVALID_PARAMS = -32602
    const val INTERNAL_ERROR = -32603

    // Application specific errors (positive numbers)
    const val UNKNOWN_COMPONENT = 900001
    const val UNKNOWN_FUNCTION = 900002
    const val PERMISSION_DENIED = 900003
    const val TIMEOUT = 900004
    const val CANCELLED = 900005
}
