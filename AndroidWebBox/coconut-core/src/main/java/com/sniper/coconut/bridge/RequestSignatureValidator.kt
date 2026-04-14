package com.sniper.coconut.bridge

import com.sniper.coconut.utils.Logger
import java.util.LinkedHashMap
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/**
 * Request Signature Validator
 *
 * HMAC-SHA256 signature verification for bridge requests:
 * - sign = HMAC(secret, method|id|timestamp|nonce|params)
 * - Timestamp tolerance check (default 5 minutes)
 * - Nonce deduplication (LRU cache, 1000 entries)
 * - Uses javax.crypto only, no new dependencies
 */
object RequestSignatureValidator {

    private const val TAG = "RequestSignature"
    private const val ALGORITHM = "HmacSHA256"
    private const val DEFAULT_TOLERANCE_MS = 5 * 60 * 1000L // 5 minutes
    private const val MAX_NONCE_CACHE = 1000

    @Volatile
    var enabled: Boolean = false

    @Volatile
    var sharedSecret: String = ""

    @Volatile
    var timestampToleranceMs: Long = DEFAULT_TOLERANCE_MS

    // LRU cache for nonce deduplication
    private val nonceCache = object : LinkedHashMap<String, Long>(MAX_NONCE_CACHE, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Long>?): Boolean {
            return size > MAX_NONCE_CACHE
        }
    }

    /**
     * Result of signature validation
     */
    sealed class SignResult {
        object Valid : SignResult()
        data class Invalid(val errorCode: String, val message: String) : SignResult()
    }

    /**
     * Validate request signature
     *
     * @param method Request method
     * @param id Request ID
     * @param timestamp Request timestamp
     * @param nonce Request nonce
     * @param paramsJson Params JSON string
     * @param sign Provided signature
     */
    @Synchronized
    fun validate(
        method: String,
        id: String,
        timestamp: Long,
        nonce: String,
        paramsJson: String,
        sign: String
    ): SignResult {
        if (!enabled) return SignResult.Valid

        // Check timestamp tolerance
        val now = System.currentTimeMillis()
        if (timestamp <= 0L || kotlin.math.abs(now - timestamp) > timestampToleranceMs) {
            Logger.w(TAG, "Timestamp expired: ts=$timestamp, now=$now, tolerance=$timestampToleranceMs")
            return SignResult.Invalid(
                com.sniper.coconut.bridge.model.ErrorCode.SIGNATURE_EXPIRED,
                "Request timestamp expired"
            )
        }

        // Check nonce reuse
        if (nonce.isEmpty()) {
            Logger.w(TAG, "Empty nonce")
            return SignResult.Invalid(
                com.sniper.coconut.bridge.model.ErrorCode.NONCE_REUSED,
                "Nonce is required when signing is enabled"
            )
        }
        if (nonceCache.containsKey(nonce)) {
            Logger.w(TAG, "Nonce reused: $nonce")
            return SignResult.Invalid(
                com.sniper.coconut.bridge.model.ErrorCode.NONCE_REUSED,
                "Nonce already used"
            )
        }

        // Compute expected signature
        val payload = "$method|$id|$timestamp|$nonce|$paramsJson"
        val expected = computeHmac(payload)

        if (expected.isEmpty()) {
            Logger.e(TAG, "Failed to compute HMAC")
            return SignResult.Invalid(
                com.sniper.coconut.bridge.model.ErrorCode.SIGNATURE_INVALID,
                "Signature verification failed"
            )
        }

        if (!constantTimeEquals(expected, sign)) {
            Logger.w(TAG, "Signature mismatch for method=$method")
            return SignResult.Invalid(
                com.sniper.coconut.bridge.model.ErrorCode.SIGNATURE_INVALID,
                "Invalid signature"
            )
        }

        // Record nonce
        nonceCache[nonce] = now
        return SignResult.Valid
    }

    /**
     * Compute HMAC-SHA256
     */
    private fun computeHmac(payload: String): String {
        return try {
            val mac = Mac.getInstance(ALGORITHM)
            val keySpec = SecretKeySpec(sharedSecret.toByteArray(Charsets.UTF_8), ALGORITHM)
            mac.init(keySpec)
            val bytes = mac.doFinal(payload.toByteArray(Charsets.UTF_8))
            bytes.joinToString("") { "%02x".format(it) }
        } catch (e: Exception) {
            Logger.e(TAG, "HMAC computation failed", e)
            ""
        }
    }

    /**
     * Constant-time string comparison to prevent timing attacks
     */
    private fun constantTimeEquals(a: String, b: String): Boolean {
        if (a.length != b.length) return false
        var result = 0
        for (i in a.indices) {
            result = result or (a[i].code xor b[i].code)
        }
        return result == 0
    }

    /**
     * Reset nonce cache
     */
    @Synchronized
    fun reset() {
        nonceCache.clear()
    }
}
