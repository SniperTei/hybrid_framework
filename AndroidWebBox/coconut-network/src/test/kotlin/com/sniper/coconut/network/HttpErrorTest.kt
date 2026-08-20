package com.sniper.coconut.network

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class HttpErrorTest {

    @Test
    fun isNetworkError_truthTable() {
        assertTrue(HttpError.isNetworkError(-1001))   // NETWORK_ERROR
        assertTrue(HttpError.isNetworkError(-1002))   // TIMEOUT_ERROR
        assertTrue(HttpError.isNetworkError(-1004))   // URL_BLOCKED（传输层拒绝）
        assertFalse(HttpError.isNetworkError(-2001))  // TOKEN_EXPIRED
        assertFalse(HttpError.isNetworkError(500))
    }

    @Test
    fun isTokenError_truthTable() {
        assertTrue(HttpError.isTokenError(-2001))
        assertTrue(HttpError.isTokenError(-2002))
        assertFalse(HttpError.isTokenError(-1001))
        assertFalse(HttpError.isTokenError(-3001))
    }

    @Test
    fun isRetryable_truthTable() {
        assertTrue(HttpError.isRetryable(-1001))      // NETWORK_ERROR
        assertTrue(HttpError.isRetryable(-1002))      // TIMEOUT_ERROR
        assertFalse(HttpError.isRetryable(-1003))     // SSL_ERROR
        assertFalse(HttpError.isRetryable(-1004))     // URL_BLOCKED
        assertFalse(HttpError.isRetryable(-2001))
    }

    @Test
    fun urlBlockedCode_existsInEnum() {
        assertEquals(-1004, HttpErrorCode.URL_BLOCKED.code)
    }
}
