package com.sniper.coconut.bridge.model

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonObject

/**
 * Bridge Request Model
 *
 * Request format:
 * {
 *   "component": "storage",   // matches Component.name
 *   "function":  "setItem",   // method on that component
 *   "params":    { ... },
 *   "id":        "unique-request-id",
 *   "bridgeToken": "..."
 * }
 *
 * Note: 'component' and 'function' are separate top-level fields (not
 * joined as "component.function" in a single 'method' field). This makes
 * routing on the native side a direct lookup by name — no string
 * splitting required.
 */
@Serializable
data class BridgeRequest(
    val component: String,
    val function: String,
    val params: JsonObject? = null,
    val id: String,
    val bridgeToken: String = ""
) {
    companion object {
        private val NAME_REGEX = Regex("^[a-zA-Z][a-zA-Z0-9_]*$")

        /**
         * Validate component / function name format.
         * Same rules for both: start with letter, then letters/digits/underscore.
         */
        fun isValidName(name: String): Boolean {
            return name.matches(NAME_REGEX)
        }
    }

    /**
     * Joined "component.function" — convenience for logging / metrics /
     * rate limiting, where a single string is still useful as a key.
     */
    val method: String
        get() = "$component.$function"

    /**
     * Validate request
     */
    fun validate(): ValidationResult {
        when {
            !isValidName(component) -> {
                return ValidationResult(false, "Invalid component name: $component")
            }
            !isValidName(function) -> {
                return ValidationResult(false, "Invalid function name: $function")
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
