package com.sniper.coconut.bridge

import com.sniper.coconut.utils.Logger
import java.util.UUID

/**
 * Bridge Token Manager
 *
 * Generates a random UUID token per session, injected into JS.
 * Each bridge call must carry the correct token to prevent JS injection.
 */
object BridgeTokenManager {

    private const val TAG = "BridgeTokenManager"

    @Volatile
    private var token: String = ""

    @Volatile
    var enabled: Boolean = true

    /**
     * Generate a new token for the current session
     */
    fun generateToken(): String {
        token = UUID.randomUUID().toString()
        Logger.d(TAG, "Bridge token generated")
        return token
    }

    /**
     * Get current token
     */
    fun getToken(): String = token

    /**
     * Validate the given token against the current one
     */
    fun validateToken(requestToken: String): Boolean {
        if (!enabled) return true
        // Fail-closed: an empty token means "never initialized" or "reset without
        // regenerate". Previously this returned true (fail-open), which created a
        // silent bypass window if reset() was called at runtime without an
        // immediate generateToken(). Returning false forces the caller to
        // generate a token before any bridge call can succeed.
        if (token.isEmpty()) return false
        return token == requestToken
    }

    /**
     * Reset token (e.g. on destroy)
     */
    fun reset() {
        token = ""
        Logger.d(TAG, "Bridge token reset")
    }
}
