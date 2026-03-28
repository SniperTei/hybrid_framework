package com.sniper.coconut.components.router

import android.content.Context
import android.content.Intent
import android.net.Uri
import com.sniper.coconut.component.BaseComponent
import com.sniper.coconut.component.ComponentContext
import com.sniper.coconut.component.ComponentMetadata
import com.sniper.coconut.utils.Logger
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Router Component
 *
 * Unified routing protocol for navigating between H5 and native pages.
 *
 * Protocol:
 * - coconut://native/xxx?params   -> Open native page
 * - coconut://h5/xxx?params       -> Open H5 page in WebView
 * - http(s)://xxx                  -> Open URL in WebView
 *
 * H5 usage:
 *   Coconut.call('router.open', { url: 'coconut://native/settings' })
 *   Coconut.call('router.open', { url: 'coconut://h5/about' })
 *   Coconut.call('router.open', { url: 'https://example.com', isNewWindow: true })
 *   Coconut.call('router.back')
 *   Coconut.call('router.getScheme')
 */
@ComponentMetadata(
    name = "router",
    version = "1.0.0",
    description = "Unified routing protocol component"
)
class RouterComponent : BaseComponent() {

    override val name = "router"
    override val version = "1.0.0"
    override val description = "Unified routing protocol component"

    private var componentContext: ComponentContext? = null

    override suspend fun onInit(ctx: ComponentContext) {
        componentContext = ctx
    }

    override suspend fun handle(function: String, params: JsonObject?): JsonElement {
        return when (function) {
            "open" -> open(params)
            "back" -> back()
            "getScheme" -> getScheme()
            else -> functionNotSupportedError(function)
        }
    }

    /**
     * Open a URL via routing protocol
     *
     * Supported formats:
     * - coconut://native/pageName?key=value  -> Open native page
     * - coconut://h5/path?key=value          -> Open H5 page
     * - https://example.com                  -> Open URL
     */
    private fun open(params: JsonObject?): JsonElement {
        val url = getParam(params, "url")
        if (url.isEmpty()) {
            return error("900001", "URL is required")
        }

        val isNewWindow = getBoolParam(params, "isNewWindow", false)
        val context = componentContext?.applicationContext ?: return error("900010", "Context not available")

        Logger.d(name, "Routing to: $url (newWindow: $isNewWindow)")

        return when {
            url.startsWith(SCHEME_COCONUT_NATIVE) -> handleNativeRoute(url, context)
            url.startsWith(SCHEME_COCONUT_H5) -> handleH5Route(url, isNewWindow)
            url.startsWith("http://") || url.startsWith("https://") -> handleHttpRoute(url, isNewWindow)
            else -> error("900001", "Unsupported URL scheme: $url")
        }
    }

    /**
     * Handle coconut://native/xxx routes
     * Subclasses should override to register native page handlers
     */
    protected open fun handleNativeRoute(url: String, context: Context): JsonElement {
        val uri = Uri.parse(url)
        val pageName = uri.host ?: ""
        val params = uri.queryParameterNames.associateWith { uri.getQueryParameter(it) ?: "" }

        Logger.d(name, "Native route: page=$pageName, params=$params")

        // Emit route event via WebView
        val webView = componentContext?.currentWebView
        webView?.post {
            webView.evaluateJavascript(
                "if (typeof window.__coconutNativeRoute === 'function') { window.__coconutNativeRoute('$pageName', ${toJsonString(params)}); }",
                null
            )
        }

        return buildJsonObject {
            put("routed", JsonPrimitive(true))
            put("type", JsonPrimitive("native"))
            put("page", JsonPrimitive(pageName))
        }.let { success(it) }
    }

    /**
     * Handle coconut://h5/xxx routes
     */
    protected open fun handleH5Route(url: String, isNewWindow: Boolean): JsonElement {
        val uri = Uri.parse(url)
        val path = uri.path?.trimStart('/') ?: ""
        val query = uri.query ?: ""
        val fullUrl = if (query.isNotEmpty()) "$path?$query" else path

        Logger.d(name, "H5 route: path=$fullUrl, newWindow=$isNewWindow")

        val webView = componentContext?.currentWebView
        if (webView != null && !isNewWindow) {
            // Load in current WebView
            webView.post {
                webView.evaluateJavascript(
                    "if (typeof window.__coconutH5Route === 'function') { window.__coconutH5Route('$fullUrl'); }",
                    null
                )
            }
        }

        return buildJsonObject {
            put("routed", JsonPrimitive(true))
            put("type", JsonPrimitive("h5"))
            put("path", JsonPrimitive(fullUrl))
        }.let { success(it) }
    }

    /**
     * Handle http(s) routes
     */
    protected open fun handleHttpRoute(url: String, isNewWindow: Boolean): JsonElement {
        Logger.d(name, "HTTP route: $url, newWindow=$isNewWindow")

        val webView = componentContext?.currentWebView
        if (webView != null && !isNewWindow) {
            webView.post { webView.loadUrl(url) }
        }

        return buildJsonObject {
            put("routed", JsonPrimitive(true))
            put("type", JsonPrimitive("http"))
            put("url", JsonPrimitive(url))
        }.let { success(it) }
    }

    /**
     * Go back in WebView history
     */
    private fun back(): JsonElement {
        val webView = componentContext?.currentWebView
        webView?.post {
            if (webView.canGoBack()) {
                webView.goBack()
            }
        }
        return buildJsonObject {
            put("success", JsonPrimitive(true))
        }.let { success(it) }
    }

    /**
     * Get current route scheme info
     */
    private fun getScheme(): JsonElement {
        return buildJsonObject {
            put("scheme", JsonPrimitive("coconut"))
            put("nativePrefix", JsonPrimitive(SCHEME_COCONUT_NATIVE))
            put("h5Prefix", JsonPrimitive(SCHEME_COCONUT_H5))
        }.let { success(it) }
    }

    private fun toJsonString(map: Map<String, String?>): String {
        val entries = map.entries.joinToString(",") { "\"${it.key}\":\"${it.value}\"" }
        return "{$entries}"
    }

    companion object {
        const val SCHEME_COCONUT_NATIVE = "coconut://native/"
        const val SCHEME_COCONUT_H5 = "coconut://h5/"
    }

    override suspend fun onCleanup() {
        componentContext = null
    }
}
