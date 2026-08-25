package com.sniper.coconut.nav

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.jsonObject

/**
 * Container navigation-bar configuration (v3.5.0 container-nav).
 *
 * All fields are nullable override slots: null = inherit from the next level
 * down in the three-tier chain
 *
 *   forward header (per-call) > template subclass default > CoconutConfig.nav (global)
 *
 * merged field-by-field via [merge]. Resolved defaults come from [default]:
 * visible bar, AUTO title (syncs document.title), AUTO close policy
 * (× only when the WebView history is exhausted).
 *
 * JSON override shape (forward header / EXTRA_NAV_JSON):
 * `{"visible":false, "title":"订单详情"|"auto", "closePolicy":"always"|"auto",
 *   "leftButtonText":"取消", "rightButtonText":"分享"}`
 */
class NavConfig(
    var visible: Boolean? = null,
    var titleMode: TitleMode? = null,
    var titleText: String? = null,
    var closePolicy: ClosePolicy? = null,
    var leftButtonText: String? = null,
    var rightButtonText: String? = null,
) {

    enum class TitleMode { AUTO, FIXED }
    enum class ClosePolicy { AUTO, ALWAYS }

    /**
     * Whether the close (×) button should show at this history state.
     * ALWAYS shows unconditionally; AUTO (and unresolved null) only at the
     * stack root (canGoBack=false) so the user always has an exit.
     */
    fun shouldShowClose(canGoBack: Boolean): Boolean = when (closePolicy) {
        ClosePolicy.ALWAYS -> true
        else -> !canGoBack
    }

    fun copy(): NavConfig = NavConfig(
        visible = visible,
        titleMode = titleMode,
        titleText = titleText,
        closePolicy = closePolicy,
        leftButtonText = leftButtonText,
        rightButtonText = rightButtonText,
    )

    companion object {
        /** Full default: visible bar, AUTO title, AUTO close policy. */
        fun default(): NavConfig = NavConfig(
            visible = true,
            titleMode = TitleMode.AUTO,
            closePolicy = ClosePolicy.AUTO,
        )

        /** Field-by-field merge; null fields in [override] inherit from [base]. */
        fun merge(base: NavConfig, override: NavConfig): NavConfig = NavConfig(
            visible = override.visible ?: base.visible,
            titleMode = override.titleMode ?: base.titleMode,
            titleText = override.titleText ?: base.titleText,
            closePolicy = override.closePolicy ?: base.closePolicy,
            leftButtonText = override.leftButtonText ?: base.leftButtonText,
            rightButtonText = override.rightButtonText ?: base.rightButtonText,
        )

        /**
         * Parse a JSON override object. Returns null on malformed JSON —
         * callers treat that as "no override" rather than crashing the launch.
         */
        fun parseOverride(json: String): NavConfig? = try {
            val obj = Json.parseToJsonElement(json).jsonObject
            NavConfig(
                visible = (obj["visible"] as? JsonPrimitive)?.booleanOrNull,
                titleMode = parseTitleMode(obj["title"] as? JsonPrimitive),
                titleText = parseTitleText(obj["title"] as? JsonPrimitive),
                closePolicy = parseClosePolicy(obj["closePolicy"] as? JsonPrimitive),
                leftButtonText = (obj["leftButtonText"] as? JsonPrimitive)?.takeIf { it.isString }?.content,
                rightButtonText = (obj["rightButtonText"] as? JsonPrimitive)?.takeIf { it.isString }?.content,
            )
        } catch (e: Exception) {
            null
        }

        // "auto" (case-insensitive) → AUTO mode; any other string → FIXED with that text
        private fun parseTitleMode(title: JsonPrimitive?): TitleMode? {
            if (title == null || !title.isString) return null
            return if (title.content.equals("auto", ignoreCase = true)) TitleMode.AUTO else TitleMode.FIXED
        }

        private fun parseTitleText(title: JsonPrimitive?): String? {
            if (title == null || !title.isString) return null
            return if (title.content.equals("auto", ignoreCase = true)) null else title.content
        }

        private fun parseClosePolicy(policy: JsonPrimitive?): ClosePolicy? {
            if (policy == null || !policy.isString) return null
            return if (policy.content.equals("always", ignoreCase = true)) ClosePolicy.ALWAYS else null
        }
    }
}
