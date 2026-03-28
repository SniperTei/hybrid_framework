package com.sniper.coconut.component

import android.app.Activity
import android.webkit.WebView

/**
 * Component Host Interface
 *
 * Implemented by the Activity that hosts the WebView.
 * Provides components with access to Activity-level features
 * such as permission requests, dialogs, and intents.
 *
 * Components access the host through [ComponentContext.host].
 */
interface ComponentHost {

    /**
     * Get the host Activity
     */
    fun getActivity(): Activity?

    /**
     * Get the WebView instance
     * Named to avoid JVM signature clash with Kotlin `webView` property
     */
    fun getHostWebView(): WebView?

    /**
     * Run an action on the main thread
     */
    fun runOnMainThread(action: () -> Unit)
}
