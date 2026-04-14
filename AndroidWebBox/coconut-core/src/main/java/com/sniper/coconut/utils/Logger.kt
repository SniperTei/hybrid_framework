package com.sniper.coconut.utils

import android.util.Log

/**
 * Coconut SDK Logger
 *
 * Provides structured logging with timing and performance tracking.
 */
object Logger {

    private const val TAG = "CoconutSDK"

    enum class Level {
        DEBUG, INFO, WARN, ERROR, NONE
    }

    private var isDebug = true
    private var minLevel = Level.DEBUG

    // Performance timers
    private val timers = HashMap<String, Long>()

    /**
     * Set debug mode
     */
    fun setDebugMode(debug: Boolean) {
        isDebug = debug
        if (debug) {
            minLevel = Level.DEBUG
        } else {
            minLevel = Level.WARN
        }
    }

    /**
     * Set minimum log level
     */
    fun setLogLevel(level: Level) {
        minLevel = level
    }

    /**
     * Debug log
     */
    fun d(tag: String, message: String) {
        if (isDebug && minLevel.ordinal <= Level.DEBUG.ordinal) {
            Log.d(TAG, "[$tag] $message")
        }
    }

    /**
     * Info log
     */
    fun i(tag: String, message: String) {
        if (minLevel.ordinal <= Level.INFO.ordinal) {
            Log.i(TAG, "[$tag] $message")
        }
    }

    /**
     * Warning log
     */
    fun w(tag: String, message: String) {
        if (minLevel.ordinal <= Level.WARN.ordinal) {
            Log.w(TAG, "[$tag] $message")
        }
    }

    /**
     * Error log
     */
    fun e(tag: String, message: String, throwable: Throwable? = null) {
        if (minLevel.ordinal <= Level.ERROR.ordinal) {
            if (throwable != null) {
                Log.e(TAG, "[$tag] $message", throwable)
            } else {
                Log.e(TAG, "[$tag] $message")
            }
        }
    }

    // ---- Performance Timing ----

    /**
     * Start a performance timer
     */
    fun startTimer(timerName: String) {
        timers[timerName] = System.currentTimeMillis()
    }

    /**
     * End a performance timer and log the duration
     * @return duration in ms, or -1 if timer was not started
     */
    fun endTimer(tag: String, timerName: String): Long {
        val startTime = timers.remove(timerName) ?: return -1
        val duration = System.currentTimeMillis() - startTime
        if (isDebug && minLevel.ordinal <= Level.DEBUG.ordinal) {
            Log.d(TAG, "[$tag] ⏱ $timerName: ${duration}ms")
        }
        return duration
    }

    // ---- Bridge Call Logging ----

    /**
     * Log a bridge call start
     */
    fun logBridgeCallStart(method: String, requestId: String) {
        if (isDebug && minLevel.ordinal <= Level.DEBUG.ordinal) {
            startTimer("bridge_$requestId")
            Log.d(TAG, "[Bridge] → #$requestId $method")
        }
    }

    /**
     * Log a bridge call success
     */
    fun logBridgeCallSuccess(method: String, requestId: String) {
        if (isDebug && minLevel.ordinal <= Level.DEBUG.ordinal) {
            val duration = endTimer("Bridge", "bridge_$requestId")
            Log.d(TAG, "[Bridge] ✓ #$requestId $method (${duration}ms)")
        }
    }

    /**
     * Log a bridge call error
     */
    fun logBridgeCallError(method: String, requestId: String, errorCode: String, message: String) {
        if (minLevel.ordinal <= Level.WARN.ordinal) {
            val duration = endTimer("Bridge", "bridge_$requestId")
            Log.w(TAG, "[Bridge] ✗ #$requestId $method → [$errorCode] $message (${duration}ms)")
        }
    }

    /**
     * Log a bridge call validation failure
     */
    fun logBridgeCallValidation(method: String, requestId: String, reason: String) {
        if (minLevel.ordinal <= Level.WARN.ordinal) {
            Log.w(TAG, "[Bridge] ⚠ #$requestId $method validation failed: $reason")
        }
    }
}
