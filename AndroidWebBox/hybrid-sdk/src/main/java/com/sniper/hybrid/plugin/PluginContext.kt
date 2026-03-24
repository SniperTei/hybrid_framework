package com.sniper.hybrid.plugin

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.webkit.WebView
import androidx.fragment.app.Fragment
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner

/**
 * 插件上下文，提供插件运行所需的环境信息
 */
class PluginContext(
    private val context: Context,
    private val webView: WebView?,
    private val lifecycleOwner: LifecycleOwner?
) {
    /**
     * 获取Context
     */
    fun getContext(): Context = context

    /**
     * 获取Activity（如果可用）
     */
    fun getActivity(): Activity? {
        return when {
            context is Activity -> context
            lifecycleOwner is Activity -> lifecycleOwner as Activity
            else -> null
        }
    }

    /**
     * 获取Fragment（如果可用）
     */
    fun getFragment(): Fragment? {
        return lifecycleOwner as? Fragment
    }

    /**
     * 获取WebView实例
     */
    fun getWebView(): WebView? = webView

    /**
     * 获取Lifecycle
     */
    fun getLifecycle(): Lifecycle? = lifecycleOwner?.lifecycle

    /**
     * 启动Activity
     */
    fun startActivity(intent: Intent) {
        context.startActivity(intent)
    }

    /**
     * 启动Activity并等待结果
     */
    fun startActivityForResult(intent: Intent, requestCode: Int) {
        getActivity()?.startActivityForResult(intent, requestCode)
    }

    /**
     * 检查生命周期状态
     */
    fun isLifecycleActive(): Boolean {
        return getLifecycle()?.currentState?.isAtLeast(Lifecycle.State.STARTED) == true
    }

    /**
     * 执行在主线程
     */
    fun runOnMainThread(runnable: Runnable) {
        (context as? Activity)?.runOnUiThread(runnable)
            ?: (getFragment()?.view?.context as? Activity)?.runOnUiThread(runnable)
            ?: runnable.run()
    }

    /**
     * 请求权限
     */
    fun requestPermissions(permissions: Array<String>, requestCode: Int) {
        getActivity()?.requestPermissions(permissions, requestCode)
    }
}
