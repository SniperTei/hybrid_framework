package com.sniper.coconut.components.clipboard

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import com.sniper.coconut.component.BaseComponent
import com.sniper.coconut.component.ComponentContext
import com.sniper.coconut.component.ComponentMetadata
import com.sniper.coconut.utils.Logger
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Clipboard Component
 *
 * Provides clipboard read/write via native ClipboardManager.
 */
@ComponentMetadata(
    name = "clipboard",
    version = "1.0.0",
    description = "Clipboard read/write component"
)
class ClipboardComponent : BaseComponent() {

    override val name = "clipboard"
    override val version = "1.0.0"
    override val description = "Clipboard read/write component"

    private var context: Context? = null
    private val clipboardManager: ClipboardManager?
        get() = context?.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager

    override suspend fun onInit(ctx: ComponentContext) {
        context = ctx.applicationContext
    }

    override suspend fun handle(function: String, params: JsonObject?): JsonElement {
        return when (function) {
            "getText" -> getText()
            "setText" -> setText(params)
            "hasText" -> hasText()
            "clear" -> clear()
            else -> functionNotSupportedError(function)
        }
    }

    private fun getText(): JsonElement {
        val clip = clipboardManager?.primaryClip
        val text = if (clip != null && clip.itemCount > 0) {
            clip.getItemAt(0)?.text?.toString() ?: ""
        } else {
            ""
        }
        return buildJsonObject {
            put("text", JsonPrimitive(text))
            put("hasText", JsonPrimitive(text.isNotEmpty()))
        }.let { success(it) }
    }

    private fun setText(params: JsonObject?): JsonElement {
        val text = getParam(params, "text")
        if (text.isEmpty()) {
            return paramValidationError("Text cannot be empty")
        }
        val clip = ClipData.newPlainText("text", text)
        clipboardManager?.setPrimaryClip(clip)
        Logger.d(name, "Clipboard set: ${text.take(50)}")
        return buildJsonObject {
            put("success", JsonPrimitive(true))
        }.let { success(it) }
    }

    private fun hasText(): JsonElement {
        val hasText = clipboardManager?.hasPrimaryClip() == true
        return buildJsonObject {
            put("hasText", JsonPrimitive(hasText))
        }.let { success(it) }
    }

    private fun clear(): JsonElement {
        clipboardManager?.let {
            if (it.hasPrimaryClip()) {
                it.clearPrimaryClip()
            }
        }
        return buildJsonObject {
            put("success", JsonPrimitive(true))
        }.let { success(it) }
    }

    override suspend fun onCleanup() {
        context = null
    }
}
