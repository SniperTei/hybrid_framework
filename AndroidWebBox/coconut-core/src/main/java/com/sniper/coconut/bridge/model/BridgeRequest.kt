package com.sniper.coconut.bridge.model

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonObject

/**
 * Bridge Request Model
 *
 * Request format:
 * {
 *   "method": "component.function",
 *   "params": { ... },
 *   "id": "unique-request-id"
 * }
 */
@Serializable
data class BridgeRequest(
    val method: String,
    val params: JsonObject? = null,
    val id: String,
    val bridgeToken: String = ""
) {
    companion object {
        /**
         * Validate method format: component.function
         */
        fun isValidMethod(method: String): Boolean {
            return method.matches(Regex("^[a-zA-Z][a-zA-Z0-9_]*\\.[a-zA-Z][a-zA-Z0-9_]*$"))
        }

        /**
         * Extract component name from method
         */
        fun extractComponent(method: String): String {
            return method.substringBefore(".")
        }

        /**
         * Extract function name from method
         */
        fun extractFunction(method: String): String {
            return method.substringAfter(".")
        }
    }

    /**
     * Get component name
     */
    val componentName: String
        get() = extractComponent(method)

    /**
     * Get function name
     */
    val functionName: String
        get() = extractFunction(method)

    /**
     * Validate request
     */
    fun validate(): ValidationResult {
        when {
            !isValidMethod(method) -> {
                return ValidationResult(false, "Invalid method format: $method")
            }
            id.isBlank() -> {
                return ValidationResult(false, "Request ID cannot be blank")
            }
            else -> {
                return ValidationResult(true)
            }
        }
    }
}

/**
 * Validation result
 */
data class ValidationResult(
    val isValid: Boolean,
    val message: String = ""
)
