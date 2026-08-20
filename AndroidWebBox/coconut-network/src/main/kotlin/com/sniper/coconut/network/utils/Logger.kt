package com.sniper.coconut.network.utils

/**
 * CoconutNetwork Logger
 *
 * JVM 模块没有 android.util.Log — console 实现 + 可替换 sink。
 * 宿主 App 可把 sink 接到系统日志（对齐 CoconutSDK Logger API 以便无缝切换）。
 */
object Logger {
    /** 可替换的日志出口（level: d/i/w/e） */
    var sink: (level: String, tag: String, message: String) -> Unit =
        { level, tag, message -> println("[$level][$tag] $message") }

    fun d(tag: String, message: String) = sink("d", tag, message)

    fun i(tag: String, message: String) = sink("i", tag, message)

    fun w(tag: String, message: String) = sink("w", tag, message)

    fun e(tag: String, message: String) = sink("e", tag, message)
}
