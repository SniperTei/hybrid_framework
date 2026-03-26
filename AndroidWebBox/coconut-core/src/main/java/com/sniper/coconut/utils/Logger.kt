package com.sniper.coconut.utils

import android.util.Log

/**
 * Logger Utility
 *
 * Provides logging with consistent format for Coconut SDK
 */
object Logger {

    private const val TAG = "CoconutSDK"

    private var isDebug = true

    /**
     * Set debug mode
     */
    fun setDebugMode(debug: Boolean) {
        isDebug = debug
    }

    /**
     * Debug log
     */
    fun d(tag: String, message: String) {
        if (isDebug) {
            Log.d(TAG, "[$tag] $message")
        }
    }

    /**
     * Info log
     */
    fun i(tag: String, message: String) {
        if (isDebug) {
            Log.i(TAG, "[$tag] $message")
        }
    }

    /**
     * Warning log
     */
    fun w(tag: String, message: String) {
        Log.w(TAG, "[$tag] $message")
    }

    /**
     * Error log
     */
    fun e(tag: String, message: String, throwable: Throwable? = null) {
        if (throwable != null) {
            Log.e(TAG, "[$tag] $message", throwable)
        } else {
            Log.e(TAG, "[$tag] $message")
        }
    }
}
