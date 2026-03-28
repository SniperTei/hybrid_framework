package com.sniper.coconut.components.stack

import android.webkit.WebView
import com.sniper.coconut.component.BaseComponent
import com.sniper.coconut.component.ComponentContext
import com.sniper.coconut.component.ComponentMetadata
import com.sniper.coconut.utils.Logger
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Stack Component
 *
 * WebView page stack management.
 * Tracks page history and provides stack operations.
 *
 * H5 usage:
 *   Coconut.call('stack.push', { url: '/about' })
 *   Coconut.call('stack.pop')
 *   Coconut.call('stack.backTo', { index: 0 })
 *   Coconut.call('stack.getSize')
 *   Coconut.call('stack.getStack')
 *   Coconut.call('stack.replace', { url: '/login' })
 */
@ComponentMetadata(
    name = "stack",
    version = "1.0.0",
    description = "WebView page stack management component"
)
class StackComponent : BaseComponent() {

    override val name = "stack"
    override val version = "1.0.0"
    override val description = "WebView page stack management component"

    private var componentContext: ComponentContext? = null

    override suspend fun onInit(ctx: ComponentContext) {
        componentContext = ctx
    }

    override suspend fun handle(function: String, params: JsonObject?): JsonElement {
        return when (function) {
            "push" -> push(params)
            "pop" -> pop()
            "replace" -> replace(params)
            "backTo" -> backTo(params)
            "getSize" -> getSize()
            "getStack" -> getStack()
            "canGoBack" -> canGoBack()
            else -> functionNotSupportedError(function)
        }
    }

    private fun getWebView(): WebView? = componentContext?.currentWebView

    /**
     * Push a new URL onto the stack (navigate forward)
     */
    private fun push(params: JsonObject?): JsonElement {
        val url = getParam(params, "url")
        if (url.isEmpty()) {
            return error("900001", "URL is required")
        }

        val webView = getWebView() ?: return error("900010", "WebView not available")
        webView.post { webView.loadUrl(url) }

        Logger.d(name, "Push: $url")
        return buildJsonObject {
            put("success", JsonPrimitive(true))
            put("action", JsonPrimitive("push"))
        }.let { success(it) }
    }

    /**
     * Pop (go back one page)
     */
    private fun pop(): JsonElement {
        val webView = getWebView() ?: return error("900010", "WebView not available")

        if (webView.canGoBack()) {
            webView.post { webView.goBack() }
            Logger.d(name, "Pop")
            return buildJsonObject {
                put("success", JsonPrimitive(true))
                put("action", JsonPrimitive("pop"))
            }.let { success(it) }
        }

        return buildJsonObject {
            put("success", JsonPrimitive(false))
            put("message", JsonPrimitive("Cannot go back, at bottom of stack"))
        }.let { success(it) }
    }

    /**
     * Replace current page
     */
    private fun replace(params: JsonObject?): JsonElement {
        val url = getParam(params, "url")
        if (url.isEmpty()) {
            return error("900001", "URL is required")
        }

        val webView = getWebView() ?: return error("900010", "WebView not available")

        // Use JS to replace (location.replace) so it doesn't add to history
        webView.post {
            webView.evaluateJavascript("window.location.replace('$url');", null)
        }

        Logger.d(name, "Replace: $url")
        return buildJsonObject {
            put("success", JsonPrimitive(true))
            put("action", JsonPrimitive("replace"))
        }.let { success(it) }
    }

    /**
     * Go back to a specific position in the stack
     * params: { "index": 0 } or { "url": "..." }
     */
    private fun backTo(params: JsonObject?): JsonElement {
        val webView = getWebView() ?: return error("900010", "WebView not available")

        val targetIndex = getIntParam(params, "index", -1)
        val targetUrl = getParam(params, "url")

        val backList = webView.copyBackForwardList()
        val currentIndex = backList.currentIndex

        when {
            targetIndex >= 0 -> {
                // Go back by index
                val stepsBack = currentIndex - targetIndex
                if (stepsBack > 0 && webView.canGoBackOrForward(-stepsBack)) {
                    webView.post { webView.goBackOrForward(-stepsBack) }
                    Logger.d(name, "BackTo index: $targetIndex (${stepsBack} steps)")
                } else {
                    return error("900001", "Invalid stack index: $targetIndex (current: $currentIndex)")
                }
            }
            targetUrl.isNotEmpty() -> {
                // Find URL in history and go back to it
                var found = false
                for (i in currentIndex - 1 downTo 0) {
                    val item = backList.getItemAtIndex(i)
                    if (item?.url?.contains(targetUrl) == true) {
                        val stepsBack = currentIndex - i
                        webView.post { webView.goBackOrForward(-stepsBack) }
                        Logger.d(name, "BackTo url: $targetUrl (${stepsBack} steps)")
                        found = true
                        break
                    }
                }
                if (!found) {
                    return error("900001", "URL not found in stack: $targetUrl")
                }
            }
            else -> {
                return error("900001", "index or url parameter required")
            }
        }

        return buildJsonObject {
            put("success", JsonPrimitive(true))
            put("action", JsonPrimitive("backTo"))
        }.let { success(it) }
    }

    /**
     * Get current stack size
     */
    private fun getSize(): JsonElement {
        val webView = getWebView() ?: return error("900010", "WebView not available")
        val backList = webView.copyBackForwardList()

        return buildJsonObject {
            put("size", JsonPrimitive(backList.size))
            put("currentIndex", JsonPrimitive(backList.currentIndex))
        }.let { success(it) }
    }

    /**
     * Get full page stack info
     */
    private fun getStack(): JsonElement {
        val webView = getWebView() ?: return error("900010", "WebView not available")
        val backList = webView.copyBackForwardList()

        val pages = (0 until backList.size).mapNotNull { i ->
            val item = backList.getItemAtIndex(i)
            item?.let {
                buildJsonObject {
                    put("index", JsonPrimitive(i))
                    put("url", JsonPrimitive(it.url ?: ""))
                    put("title", JsonPrimitive(it.title ?: ""))
                    put("isCurrent", JsonPrimitive(i == backList.currentIndex))
                }
            }
        }

        return buildJsonObject {
            put("currentIndex", JsonPrimitive(backList.currentIndex))
            put("totalSize", JsonPrimitive(backList.size))
            put("pages", kotlinx.serialization.json.buildJsonArray { pages.forEach { add(it) } })
        }.let { success(it) }
    }

    /**
     * Check if can go back
     */
    private fun canGoBack(): JsonElement {
        val webView = getWebView()
        val canBack = webView?.canGoBack() == true

        return buildJsonObject {
            put("canGoBack", JsonPrimitive(canBack))
        }.let { success(it) }
    }

    override suspend fun onCleanup() {
        componentContext = null
    }
}
