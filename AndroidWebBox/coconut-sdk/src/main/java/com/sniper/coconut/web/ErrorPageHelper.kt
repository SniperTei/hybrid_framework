package com.sniper.coconut.web

import android.content.Context
import android.graphics.Color
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.sniper.coconut.utils.Logger

/**
 * Error Page Helper
 *
 * Generates a native error page to display when WebView fails to load.
 * Shows error icon, message, and a retry button to prevent white screen.
 */
object ErrorPageHelper {

    private const val TAG = "ErrorPageHelper"

    /**
     * Error page configuration
     */
    data class ErrorPageConfig(
        val title: String = "页面加载失败",
        val message: String = "请检查网络连接后重试",
        val buttonText: String = "重新加载",
        val iconColor: String = "#999999",
        val buttonColor: String = "#4CAF50",
        val buttonTextColor: String = "#FFFFFF"
    )

    /**
     * Create a native error page view
     *
     * @param context Context
     * @param config Error page configuration
     * @param onRetry Callback when retry button is clicked
     * @return The error page View
     */
    fun createErrorPage(
        context: Context,
        config: ErrorPageConfig = ErrorPageConfig(),
        onRetry: () -> Unit
    ): View {
        Logger.d(TAG, "Creating error page: ${config.title}")

        val container = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(48, 0, 48, 0)
            setBackgroundColor(Color.WHITE)
        }

        // Error icon (using text as fallback since we don't have drawable resources)
        val iconView = TextView(context).apply {
            text = "⚠️"
            textSize = 56f
            gravity = Gravity.CENTER
        }
        container.addView(iconView, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            bottomMargin = 24
        })

        // Title
        val titleView = TextView(context).apply {
            text = config.title
            textSize = 20f
            setTextColor(Color.parseColor("#333333"))
            gravity = Gravity.CENTER
        }
        container.addView(titleView, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            bottomMargin = 12
        })

        // Message
        val messageView = TextView(context).apply {
            text = config.message
            textSize = 14f
            setTextColor(Color.parseColor("#999999"))
            gravity = Gravity.CENTER
        }
        container.addView(messageView, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            bottomMargin = 36
        })

        // Retry button
        val retryButton = Button(context).apply {
            text = config.buttonText
            setTextColor(Color.parseColor(config.buttonTextColor))
            setBackgroundColor(Color.parseColor(config.buttonColor))
            setPadding(48, 16, 48, 16)
            textSize = 16f
            isAllCaps = false
            setOnClickListener {
                Logger.d(TAG, "Retry button clicked")
                onRetry()
            }
        }
        container.addView(retryButton, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ))

        return container
    }
}
