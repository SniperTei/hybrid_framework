package com.sniper.coconut.bridge

import com.sniper.coconut.bridge.model.ErrorCode
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/**
 * Unit tests for [RequestSignatureValidator].
 * Mirrors iOS RequestSignatureValidatorTests.
 */
class RequestSignatureValidatorTest {

    private val secret = "test-secret-12345"

    @Before
    fun setUp() {
        RequestSignatureValidator.reset()
        RequestSignatureValidator.enabled = true
        RequestSignatureValidator.sharedSecret = secret
        // Tighten tolerance so deliberate timestamp offsets are clearly outside the window.
        RequestSignatureValidator.timestampToleranceMs = 300_000L
    }

    @After
    fun tearDown() {
        RequestSignatureValidator.reset()
        RequestSignatureValidator.enabled = false
        RequestSignatureValidator.sharedSecret = ""
        RequestSignatureValidator.timestampToleranceMs = 5 * 60 * 1000L
    }

    private fun computeExpected(method: String, id: String, ts: Long, nonce: String, params: String): String {
        val payload = "$method|$id|$ts|$nonce|$params"
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(secret.toByteArray(Charsets.UTF_8), "HmacSHA256"))
        val bytes = mac.doFinal(payload.toByteArray(Charsets.UTF_8))
        return bytes.joinToString("") { "%02x".format(it) }
    }

    private fun validSign(
        method: String = "device.getInfo",
        id: String = "req-1",
        ts: Long = System.currentTimeMillis(),
        nonce: String = "nonce-${System.nanoTime()}",
        params: String = "{}"
    ): TestData = TestData(method, id, ts, nonce, params, computeExpected(method, id, ts, nonce, params))

    data class TestData(val method: String, val id: String, val ts: Long, val nonce: String, val params: String, val sign: String)

    // ---- disabled ----

    @Test
    fun disabled_acceptsAnySignature() {
        RequestSignatureValidator.enabled = false
        val result = RequestSignatureValidator.validate(
            method = "device.getInfo",
            id = "req-1",
            timestamp = System.currentTimeMillis(),
            nonce = "n1",
            paramsJson = "{}",
            sign = "obviously-wrong"
        )
        assertTrue(result is RequestSignatureValidator.SignResult.Valid)
    }

    // ---- happy path ----

    @Test
    fun validSignature_passesAndRecordsNonce() {
        val d = validSign(nonce = "nonce-valid")
        val first = RequestSignatureValidator.validate(d.method, d.id, d.ts, d.nonce, d.params, d.sign)
        assertTrue(first is RequestSignatureValidator.SignResult.Valid)

        // Same nonce now rejected as reused even with correct signature.
        val second = RequestSignatureValidator.validate(d.method, d.id, d.ts, d.nonce, d.params, d.sign)
        assertTrue(second is RequestSignatureValidator.SignResult.Invalid)
        assertEquals(ErrorCode.NONCE_REUSED, (second as RequestSignatureValidator.SignResult.Invalid).errorCode)
    }

    @Test
    fun reusedNonce_rejected() {
        val d = validSign(nonce = "nonce-reuse")
        RequestSignatureValidator.validate(d.method, d.id, d.ts, d.nonce, d.params, d.sign)
        val result = RequestSignatureValidator.validate(d.method, d.id, d.ts, d.nonce, d.params, d.sign)
        assertTrue(result is RequestSignatureValidator.SignResult.Invalid)
        assertEquals(ErrorCode.NONCE_REUSED, (result as RequestSignatureValidator.SignResult.Invalid).errorCode)
    }

    @Test
    fun emptyNonce_rejectedAsReused() {
        val d = validSign(nonce = "")
        val result = RequestSignatureValidator.validate(d.method, d.id, d.ts, d.nonce, d.params, d.sign)
        assertTrue(result is RequestSignatureValidator.SignResult.Invalid)
        assertEquals(ErrorCode.NONCE_REUSED, (result as RequestSignatureValidator.SignResult.Invalid).errorCode)
    }

    @Test
    fun wrongSignature_rejected() {
        val d = validSign(nonce = "nonce-wrong")
        val result = RequestSignatureValidator.validate(d.method, d.id, d.ts, d.nonce, d.params, "deadbeef")
        assertTrue(result is RequestSignatureValidator.SignResult.Invalid)
        assertEquals(ErrorCode.SIGNATURE_INVALID, (result as RequestSignatureValidator.SignResult.Invalid).errorCode)
    }

    @Test
    fun expiredTimestamp_rejected() {
        val ts = System.currentTimeMillis() - 10 * 60 * 1000L // 10 minutes ago
        val nonce = "nonce-expired"
        val sign = computeExpected("device.getInfo", "req-1", ts, nonce, "{}")
        val result = RequestSignatureValidator.validate("device.getInfo", "req-1", ts, nonce, "{}", sign)
        assertTrue(result is RequestSignatureValidator.SignResult.Invalid)
        assertEquals(ErrorCode.SIGNATURE_EXPIRED, (result as RequestSignatureValidator.SignResult.Invalid).errorCode)
    }

    @Test
    fun futureTimestamp_rejected() {
        val ts = System.currentTimeMillis() + 10 * 60 * 1000L // 10 minutes ahead
        val nonce = "nonce-future"
        val sign = computeExpected("device.getInfo", "req-1", ts, nonce, "{}")
        val result = RequestSignatureValidator.validate("device.getInfo", "req-1", ts, nonce, "{}", sign)
        assertTrue(result is RequestSignatureValidator.SignResult.Invalid)
        assertEquals(ErrorCode.SIGNATURE_EXPIRED, (result as RequestSignatureValidator.SignResult.Invalid).errorCode)
    }

    @Test
    fun zeroTimestamp_rejected() {
        val result = RequestSignatureValidator.validate(
            method = "device.getInfo",
            id = "req-1",
            timestamp = 0L,
            nonce = "nonce-zero",
            paramsJson = "{}",
            sign = "anything"
        )
        assertTrue(result is RequestSignatureValidator.SignResult.Invalid)
        assertEquals(ErrorCode.SIGNATURE_EXPIRED, (result as RequestSignatureValidator.SignResult.Invalid).errorCode)
    }

    // ---- LRU eviction ----

    @Test
    fun nonceCache_evictsOldestAfter1000Entries() {
        // Fill cache with 1000 unique nonces.
        for (i in 0 until 1000) {
            val nonce = "n-$i"
            val ts = System.currentTimeMillis()
            val sign = computeExpected("device.getInfo", "req-1", ts, nonce, "{}")
            val r = RequestSignatureValidator.validate("device.getInfo", "req-1", ts, nonce, "{}", sign)
            assertTrue("nonce $i should be accepted", r is RequestSignatureValidator.SignResult.Valid)
        }
        // Add one more — this evicts the oldest ("n-0").
        val extraNonce = "n-1000"
        val ts = System.currentTimeMillis()
        val extraSign = computeExpected("device.getInfo", "req-1", ts, extraNonce, "{}")
        assertTrue(
            RequestSignatureValidator.validate("device.getInfo", "req-1", ts, extraNonce, "{}", extraSign)
                is RequestSignatureValidator.SignResult.Valid
        )
        // "n-0" should have been evicted; resubmitting it with a fresh signature now succeeds again.
        val ts2 = System.currentTimeMillis()
        val signN0 = computeExpected("device.getInfo", "req-1", ts2, "n-0", "{}")
        val result = RequestSignatureValidator.validate("device.getInfo", "req-1", ts2, "n-0", "{}", signN0)
        assertTrue(
            "Evicted nonce n-0 should be reusable after LRU eviction",
            result is RequestSignatureValidator.SignResult.Valid
        )
    }

    // ---- reset ----

    @Test
    fun reset_clearsNonceCache() {
        val d = validSign(nonce = "nonce-reset")
        RequestSignatureValidator.validate(d.method, d.id, d.ts, d.nonce, d.params, d.sign)

        RequestSignatureValidator.reset()

        // Same nonce now acceptable again (with a fresh signature for current ts).
        val ts = System.currentTimeMillis()
        val sign = computeExpected(d.method, d.id, ts, d.nonce, d.params)
        val result = RequestSignatureValidator.validate(d.method, d.id, ts, d.nonce, d.params, sign)
        assertTrue(result is RequestSignatureValidator.SignResult.Valid)
    }
}
