package com.sniper.coconut.bridge.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Unit tests for [ErrorCode] constants and [ErrorCode.getDescription].
 * Mirrors iOS ErrorCodeTests.
 */
class ErrorCodeTest {

    private val sixDigitRegex = Regex("^\\d{6}$")

    // SUCCESS intentionally has no description entry in ErrorCode.getDescription;
    // only error codes are mapped.
    private val errorCodes: List<String> = listOf(
        ErrorCode.PARSE_ERROR,
        ErrorCode.INVALID_REQUEST,
        ErrorCode.METHOD_NOT_FOUND,
        ErrorCode.INVALID_PARAMS,
        ErrorCode.INTERNAL_ERROR,
        ErrorCode.UNKNOWN_COMPONENT,
        ErrorCode.UNKNOWN_FUNCTION,
        ErrorCode.PERMISSION_DENIED,
        ErrorCode.TIMEOUT,
        ErrorCode.CANCELLED,
        ErrorCode.DOMAIN_NOT_ALLOWED,
        ErrorCode.PARAM_VALIDATION_FAILED,
        ErrorCode.COMPONENT_NOT_INITIALIZED,
        ErrorCode.RATE_LIMIT_EXCEEDED,
        ErrorCode.BRIDGE_TOKEN_INVALID
    )

    private val allCodesIncludingSuccess: List<String> = listOf(ErrorCode.SUCCESS) + errorCodes

    @Test
    fun allCodes_areSixDigitStrings() {
        for (code in allCodesIncludingSuccess) {
            assertTrue("Code $code should match 6-digit pattern", sixDigitRegex.matches(code))
        }
    }

    @Test
    fun allCodes_areUnique() {
        assertEquals(allCodesIncludingSuccess.size, allCodesIncludingSuccess.toSet().size)
    }

    @Test
    fun success_isZero() {
        assertEquals("000000", ErrorCode.SUCCESS)
    }

    @Test
    fun getDescription_returnsNonEmptyForKnownErrorCodes() {
        for (code in errorCodes) {
            val desc = ErrorCode.getDescription(code)
            assertTrue("Description for $code should be non-empty", desc.isNotEmpty())
            assertFalse(
                "Description for known error code $code should not fall through to unknown",
                desc == "Unknown error"
            )
        }
    }

    @Test
    fun getDescription_returnsUnknownErrorForUnknownCodes() {
        assertEquals("Unknown error", ErrorCode.getDescription("999999"))
        assertEquals("Unknown error", ErrorCode.getDescription(""))
        // SUCCESS is intentionally not mapped to a description.
        assertEquals("Unknown error", ErrorCode.getDescription(ErrorCode.SUCCESS))
    }

    @Test
    fun standardErrors_startWith10000() {
        val standardErrors = listOf(
            ErrorCode.PARSE_ERROR,
            ErrorCode.INVALID_REQUEST,
            ErrorCode.METHOD_NOT_FOUND,
            ErrorCode.INVALID_PARAMS,
            ErrorCode.INTERNAL_ERROR
        )
        for (code in standardErrors) {
            assertTrue("Standard error $code should start with 1", code.startsWith("1"))
        }
    }

    @Test
    fun businessErrors_startWith20000() {
        val businessErrors = listOf(
            ErrorCode.UNKNOWN_COMPONENT,
            ErrorCode.UNKNOWN_FUNCTION,
            ErrorCode.PERMISSION_DENIED,
            ErrorCode.TIMEOUT,
            ErrorCode.CANCELLED,
            ErrorCode.DOMAIN_NOT_ALLOWED,
            ErrorCode.PARAM_VALIDATION_FAILED,
            ErrorCode.COMPONENT_NOT_INITIALIZED,
            ErrorCode.RATE_LIMIT_EXCEEDED
        )
        for (code in businessErrors) {
            assertTrue("Business error $code should start with 2", code.startsWith("2"))
        }
    }

    @Test
    fun securityErrors_startWith30000() {
        val securityErrors = listOf(
            ErrorCode.BRIDGE_TOKEN_INVALID
        )
        for (code in securityErrors) {
            assertTrue("Security error $code should start with 3", code.startsWith("3"))
        }
    }
}
