package com.sniper.androidwebbox.components

import android.content.Context
import io.mockk.mockk

/**
 * Shared mock Context for app-module component tests.
 *
 * ComponentManager.sharedContext is a lazy singleton that captures whatever
 * applicationContext was set at first initialization — test classes running
 * in the same JVM must therefore share ONE mock instance or later classes'
 * stubs silently miss (symptom: relaxed-mock defaults like "unknown").
 */
object TestSharedContext {
    val mockContext: Context = mockk(relaxed = true)
}
