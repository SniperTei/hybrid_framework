package com.sniper.coconutandroidapp.components.navigator

import android.app.Activity
import com.sniper.coconut.CoconutSDK
import com.sniper.coconut.component.BaseComponent
import com.sniper.coconut.component.ComponentContext
import com.sniper.coconut.component.ComponentMetadata
import com.sniper.coconut.nav.TemplateRegistry
import com.sniper.coconut.network.guard.UrlGuard
import com.sniper.coconut.utils.Logger
import com.sniper.coconut.web.CoconutWebActivity
import com.sniper.coconut.web.NavResultBus
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.net.URLEncoder

/**
 * Topic pushed to H5 when a custom nav-bar button is tapped ({side: left|right}).
 */
const val NAV_TOPIC_BUTTON = "nav.button"

/**
 * Topic pushed to the previous container's H5 when a child closes with a result ({result}).
 */
const val NAV_TOPIC_RESULT = "nav.result"

/**
 * Navigator Component — H5 opens/controls native containers (第 6 个组件).
 *
 * - forward({template?, url*, params?, header?}): open a new container.
 *   url passes the allowedDomains guard (coconut:// offline packages ride the
 *   internal virtual host, scheme-whitelisted); params flatten into the query
 *   string; header becomes the per-open NavConfig override JSON. Container
 *   stack capped at [MAX_STACK_DEPTH]; unregistered templates fail loudly —
 *   never silently fall back to the standard container.
 * - back(): same path as nav-bar / physical back (goBack, degrade to close).
 * - backToTop(): native viewport scroll (WebView is the scroll host).
 * - close({result?}): close this container even with history; a result is
 *   delivered to the previous container as the `nav.result` event on its
 *   next resume (NavResultBus single slot).
 *
 * Failure conventions: guard/validation → bridge error 200007 (same semantics
 * as network.request); business failures (stack limit, template 未注册, no
 * host) → code 000000 + success:false in the payload.
 *
 * Test seams: stack depth supplier, launcher and template resolver are
 * injectable; defaults read the CoconutWebActivity companion, real
 * startActivity and assets/coconut_templates.json respectively.
 */
@ComponentMetadata(
    name = "navigator",
    version = "1.0.0",
    description = "Container navigation component (forward/back/backToTop/close)",
    dependencies = []
)
class NavigatorComponent internal constructor(
    private val stackDepthSupplier: () -> Int,
    private val launcher: (String, String?, Class<*>, Activity) -> Unit,
    private val templateResolver: (() -> Map<String, Class<*>>)?,
) : BaseComponent() {

    constructor() : this(
        stackDepthSupplier = { CoconutWebActivity.stackDepth() },
        launcher = { url, navJson, targetClass, from ->
            CoconutWebActivity.start(from, url, navJson, targetClass)
        },
        templateResolver = null,
    )

    override val name = "navigator"
    override val version = "1.0.0"
    override val description = "Container navigation component (forward/back/backToTop/close)"
    override val methods = listOf("forward", "back", "backToTop", "close")

    private var context: ComponentContext? = null

    override suspend fun onInit(context: ComponentContext) {
        this.context = context
    }

    override suspend fun handle(function: String, params: JsonObject?): JsonElement {
        return when (function) {
            "forward" -> forward(params)
            "back" -> back()
            "backToTop" -> backToTop()
            "close" -> close(params)
            else -> functionNotSupportedError(function)
        }
    }

    // ---- forward ----

    private suspend fun forward(params: JsonObject?): JsonElement {
        val url = getParam(params, "url")
        if (url.isEmpty()) {
            return error("200007", "url is required")
        }

        // Outbound guard (container has no address bar — phishing defense):
        // http(s) URLs go through UrlGuard exactly like network.request;
        // coconut:// offline packages are scheme-whitelisted (moduleId is not
        // a domain; they ride the app-internal virtual host).
        if (!url.startsWith("coconut://")) {
            val domains = try {
                if (CoconutSDK.isInitialized()) CoconutSDK.getConfig().allowedDomains else emptyList()
            } catch (e: Throwable) {
                emptyList<String>()
            }
            val guard = UrlGuard.validate(url, domains)
            if (!guard.allowed) {
                return error("200007", "forward blocked: ${guard.reason}")
            }
        }

        if (stackDepthSupplier() >= MAX_STACK_DEPTH) {
            return businessFailure("container stack limit reached ($MAX_STACK_DEPTH)")
        }

        val templateName = getParam(params, "template")
        val targetClass = if (templateName.isNotEmpty()) {
            resolveTemplates()[templateName]
                ?: return businessFailure("template not registered: $templateName")
        } else {
            CoconutWebActivity::class.java
        }

        val ctx = context ?: return businessFailure("component not initialized")
        val activity = ctx.currentActivity ?: return businessFailure("no active container")
        if (activity.isFinishing) {
            return businessFailure("host activity is finishing")
        }

        val finalUrl = appendQuery(url, params?.get("params") as? JsonObject)
        val navJson = (params?.get("header") as? JsonObject)?.toString()

        launcher(finalUrl, navJson, targetClass, activity)
        return ack()
    }

    /**
     * Flatten a flat kv object into a URL-encoded query string and append it
     * (merged with `&` when the url already carries a query).
     */
    internal fun appendQuery(url: String, params: JsonObject?): String {
        if (params == null || params.isEmpty()) return url
        val query = params.entries.joinToString("&") { (k, v) ->
            val value = (v as? JsonPrimitive)?.content ?: v.toString()
            "${URLEncoder.encode(k, "UTF-8")}=${URLEncoder.encode(value, "UTF-8")}"
        }
        return if (url.contains('?')) "$url&$query" else "$url?$query"
    }

    // ---- back / backToTop / close ----

    private fun back(): JsonElement {
        val ctx = context ?: return businessFailure("component not initialized")
        val activity = ctx.currentActivity ?: return businessFailure("no active container")
        val webView = ctx.currentWebView ?: return businessFailure("no active webview")
        activity.runOnUiThread {
            if (webView.canGoBack()) webView.goBack() else activity.finish()
        }
        return ack()
    }

    private fun backToTop(): JsonElement {
        val ctx = context ?: return businessFailure("component not initialized")
        val webView = ctx.currentWebView ?: return businessFailure("no active webview")
        // Native viewport scroll — JS window.scrollTo can't find the right
        // scroll host inside inner scrollable containers.
        ctx.currentActivity?.runOnUiThread { webView.scrollTo(0, 0) }
        return ack()
    }

    private fun close(params: JsonObject?): JsonElement {
        val ctx = context ?: return businessFailure("component not initialized")
        val activity = ctx.currentActivity ?: return businessFailure("no active container")
        params?.get("result")?.let { NavResultBus.post(it.toString()) }
        activity.runOnUiThread { activity.finish() }
        return ack()
    }

    // ---- templates ----

    private fun resolveTemplates(): Map<String, Class<*>> =
        templateResolver?.invoke() ?: loadTemplatesFromAssets()

    private fun loadTemplatesFromAssets(): Map<String, Class<*>> {
        val ctx = context?.applicationContext ?: return emptyMap()
        return try {
            val text = ctx.assets.open(TEMPLATE_ASSET).bufferedReader().use { it.readText() }
            TemplateRegistry.validate(
                TemplateRegistry.parse(text),
                NavigatorComponent::class.java.classLoader,
                CoconutWebActivity::class.java,
            )
        } catch (e: Exception) {
            Logger.w(name, "template registry unavailable: ${e.message}")
            emptyMap()
        }
    }

    // ---- helpers ----

    private fun businessFailure(message: String): JsonElement =
        success(buildJsonObject {
            put("success", false)
            put("message", message)
        })

    private fun ack(): JsonElement =
        success(buildJsonObject { put("success", true) })

    companion object {
        private const val TEMPLATE_ASSET = "coconut_templates.json"

        /** Container stack cap (self-forward loop protection). */
        const val MAX_STACK_DEPTH = 10
    }
}
