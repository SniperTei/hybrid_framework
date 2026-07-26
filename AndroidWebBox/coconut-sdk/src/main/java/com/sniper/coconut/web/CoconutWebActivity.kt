package com.sniper.coconut.web

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.webkit.JavascriptInterface
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.Toolbar
import com.sniper.coconut.CoconutSDK
import com.sniper.coconut.bridge.CoconutBridgeImpl
import com.sniper.coconut.bridge.BridgeTokenManager
import com.sniper.coconut.bridge.RequestSignatureValidator
import com.sniper.coconut.component.ComponentHost
import com.sniper.coconut.component.ComponentManager
import com.sniper.coconut.resource.OfflineResourceManager
import com.sniper.coconut.resource.CoconutResourceHolder
import com.sniper.coconut.utils.Logger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob

/**
 * CoconutWebActivity - Coconut SDK WebView Activity
 *
 * Provides a ready-to-use WebView Activity with:
 * - Native error page fallback (no white screen)
 * - Title bar customization (show/hide/custom text)
 * - Secure WebView settings
 * - Bridge security validation
 * - Loading progress indicator
 *
 * Usage:
 * ```kotlin
 * // Simple launch
 * CoconutWebActivity.start(context, "https://example.com")
 *
 * // With configuration
 * CoconutWebActivity.start(context, url) {
 *     setTitleBarVisible(true)
 *     setTitle("My Page")
 *     setEnableDebug(true)
 * }
 * ```
 */
open class CoconutWebActivity : AppCompatActivity(), ComponentHost {

    companion object {
        private const val TAG = "CoconutWebActivity"
        private const val EXTRA_URL = "extra_url"
        private const val EXTRA_ENABLE_DEBUG = "extra_enable_debug"
        private const val EXTRA_USER_AGENT = "extra_user_agent"
        private const val EXTRA_TITLE_BAR_VISIBLE = "extra_title_bar_visible"
        private const val EXTRA_TITLE_TEXT = "extra_title_text"

        @JvmStatic
        fun start(context: Context, url: String) {
            val intent = Intent(context, CoconutWebActivity::class.java)
            intent.putExtra(EXTRA_URL, url)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        }

        @JvmStatic
        fun start(context: Context, url: String, enableDebug: Boolean) {
            val intent = Intent(context, CoconutWebActivity::class.java)
            intent.putExtra(EXTRA_URL, url)
            intent.putExtra(EXTRA_ENABLE_DEBUG, enableDebug)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        }

        @JvmStatic
        fun start(context: Context, url: String, userAgent: String) {
            val intent = Intent(context, CoconutWebActivity::class.java)
            intent.putExtra(EXTRA_URL, url)
            intent.putExtra(EXTRA_USER_AGENT, userAgent)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        }

        @JvmStatic
        fun start(context: Context, url: String, enableDebug: Boolean = false, userAgent: String? = null) {
            val intent = Intent(context, CoconutWebActivity::class.java)
            intent.putExtra(EXTRA_URL, url)
            intent.putExtra(EXTRA_ENABLE_DEBUG, enableDebug)
            userAgent?.let { intent.putExtra(EXTRA_USER_AGENT, it) }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        }

        @JvmStatic
        fun startForResult(activity: Activity, url: String, requestCode: Int) {
            val intent = Intent(activity, CoconutWebActivity::class.java)
            intent.putExtra(EXTRA_URL, url)
            activity.startActivityForResult(intent, requestCode)
        }

        /**
         * Start with title bar configuration
         */
        @JvmStatic
        fun start(
            context: Context,
            url: String,
            titleBarVisible: Boolean = true,
            titleText: String? = null,
            enableDebug: Boolean = false
        ) {
            val intent = Intent(context, CoconutWebActivity::class.java)
            intent.putExtra(EXTRA_URL, url)
            intent.putExtra(EXTRA_ENABLE_DEBUG, enableDebug)
            intent.putExtra(EXTRA_TITLE_BAR_VISIBLE, titleBarVisible)
            titleText?.let { intent.putExtra(EXTRA_TITLE_TEXT, it) }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        }
    }

    // ---- Views ----
    protected lateinit var webView: WebView
        private set
    private var toolbar: Toolbar? = null
    private var progressBar: ProgressBar? = null
    private var errorPageView: View? = null
    private var rootLayout: FrameLayout? = null

    // ---- Bridge ----
    protected lateinit var bridge: CoconutBridgeImpl
        private set

    // ---- State ----
    private var currentUrl: String? = null
    @Volatile
    private var cachedPageUrl: String = ""  // Cached on main thread for bridge security check
    private var enableDebug = false
    private var customUserAgent: String? = null
    private var titleBarVisible = true
    private var titleText: String? = null
    private var isLoadingError = false

    private val activityScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Logger.i(TAG, "onCreate")

        // Read configuration from intent
        val url = intent.getStringExtra(EXTRA_URL)
        enableDebug = intent.getBooleanExtra(EXTRA_ENABLE_DEBUG, false)
        customUserAgent = intent.getStringExtra(EXTRA_USER_AGENT)
        titleBarVisible = intent.getBooleanExtra(EXTRA_TITLE_BAR_VISIBLE, true)
        titleText = intent.getStringExtra(EXTRA_TITLE_TEXT)

        if (url.isNullOrEmpty()) {
            Logger.e(TAG, "URL is empty")
            finish()
            return
        }

        currentUrl = url

        // Configure SDK
        if (enableDebug) {
            CoconutSDK.configure {
                setDebugMode(true)
                setEnableWebViewDebug(true)
            }
        }

        // Setup UI and WebView
        setupUI()
        ComponentManager.getInstance().setHost(this)  // Set this Activity as component host
        setupWebView()
        setupBridge()
        loadUrl(url)
    }

    /**
     * Setup the root UI layout with optional toolbar and progress bar
     */
    protected open fun setupUI() {
        rootLayout = FrameLayout(this).apply {
            setBackgroundColor(Color.WHITE)
        }

        // Title bar
        if (titleBarVisible) {
            toolbar = Toolbar(this).apply {
                setBackgroundColor(Color.parseColor("#FFFFFF"))
                setTitleTextColor(Color.parseColor("#333333"))
                titleText?.let { title = it }
                setNavigationOnClickListener { finish() }
            }
        }

        // Progress bar
        progressBar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            visibility = View.GONE
        }

        // Root layout
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }

        toolbar?.let { container.addView(it, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        )) }

        // WebView placeholder (will be added in setupWebView)
        container.addView(rootLayout, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            0,
            1f
        ))

        setContentView(container)
        Logger.d(TAG, "UI setup complete")
    }

    /**
     * Setup WebView with secure defaults
     */
    protected open fun setupWebView() {
        webView = WebView(this)

        // Apply secure defaults
        WebViewSecurityConfig.applySecureDefaults(webView)

        // Custom user agent
        customUserAgent?.let {
            webView.settings.userAgentString = it
        }

        // WebViewClient with error handling
        webView.webViewClient = createWebViewClient()

        // Add WebView to root layout
        rootLayout?.addView(webView, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ))

        Logger.d(TAG, "WebView setup complete")
    }

    /**
     * Create WebViewClient with error fallback
     */
    protected open fun createWebViewClient(): WebViewClient {
        return object : WebViewClient() {

            override fun shouldInterceptRequest(
                view: WebView?,
                request: WebResourceRequest?
            ): WebResourceResponse? {
                // Intercept requests for offline resources
                request?.let { req ->
                    val url = req.url.toString()
                    // Only intercept for known H5 resource paths
                    if (shouldServeOffline(url)) {
                        val resourcePath = extractResourcePath(url)
                        if (resourcePath != null) {
                            val manager = getResourceManger()
                            if (manager != null && manager.hasResource(resourcePath)) {
                                val stream = manager.getResourceStream(resourcePath)
                                if (stream != null) {
                                    val mime = manager.getMimeType(resourcePath)
                                    Logger.d(TAG, "Serving offline: $resourcePath ($mime)")
                                    return WebResourceResponse(mime, "UTF-8", stream)
                                }
                            }
                        }
                    }
                }
                return super.shouldInterceptRequest(view, request)
            }

            override fun onPageStarted(view: WebView?, url: String?, favicon: android.graphics.Bitmap?) {
                super.onPageStarted(view, url, favicon)
                isLoadingError = false
                url?.let { cachedPageUrl = it }  // Cache URL on main thread
                hideErrorPage()
                Logger.d(TAG, "Page started: $url")
                onPageStartedCallback(url)
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                Logger.d(TAG, "Page loaded: $url")
                url?.let {
                    injectBridgeJavaScript()
                    onPageFinishedCallback(it)
                }
            }

            override fun onReceivedError(
                view: WebView?,
                request: WebResourceRequest?,
                error: WebResourceError?
            ) {
                super.onReceivedError(view, request, error)
                val errorUrl = request?.url?.toString() ?: "unknown"

                // Only handle main frame errors (not subresources)
                if (request?.isForMainFrame == true) {
                    isLoadingError = true
                    showErrorPage()
                    Logger.e(TAG, "Main frame error: $errorUrl, error: ${error?.description}")
                }

                onPageErrorCallback(errorUrl, error)
            }

            override fun onReceivedHttpError(
                view: WebView?,
                request: WebResourceRequest?,
                errorResponse: android.webkit.WebResourceResponse?
            ) {
                super.onReceivedHttpError(view, request, errorResponse)
                val errorUrl = request?.url?.toString() ?: "unknown"

                if (request?.isForMainFrame == true) {
                    isLoadingError = true
                    showErrorPage()
                    Logger.e(TAG, "HTTP error: $errorUrl, status: ${errorResponse?.statusCode}")
                }
            }
        }
    }

    /**
     * Setup bridge with security validation
     */
    protected open fun setupBridge() {
        bridge = CoconutBridgeImpl(ComponentManager.getInstance())

        // Apply security config from CoconutConfig
        val config = if (CoconutSDK.isInitialized()) CoconutSDK.getConfig() else null
        config?.let { cfg ->
            // Domain whitelist
            if (cfg.allowedDomains.isNotEmpty()) {
                bridge.securityValidator.addAllowedDomain(cfg.allowedDomains.joinToString(","))
            }
            bridge.securityValidator.maxParamsSize = cfg.maxBridgeParamsSize

            // Security enhancement settings
            BridgeTokenManager.enabled = cfg.enableBridgeToken
            RequestSignatureValidator.enabled = cfg.enableRequestSigning
            RequestSignatureValidator.sharedSecret = cfg.bridgeSharedSecret
            RequestSignatureValidator.timestampToleranceMs = cfg.signingTimestampToleranceMs
        }

        // Generate bridge token for this session
        if (BridgeTokenManager.enabled) {
            BridgeTokenManager.generateToken()
        }

        webView.addJavascriptInterface(
            object {
                @JavascriptInterface
                fun call(jsonData: String): String {
                    // Pass cached URL to avoid calling webView.url on JavaBridge thread
                    return bridge.handleCall(webView, jsonData, cachedPageUrl)
                }
            },
            "CoconutBridge"
        )

        Logger.d(TAG, "Bridge setup complete")
    }

    // ---- Error Page ----

    /**
     * Show native error page
     */
    protected open fun showErrorPage() {
        if (errorPageView != null) {
            errorPageView?.visibility = View.VISIBLE
            return
        }

        errorPageView = ErrorPageHelper.createErrorPage(this) {
            hideErrorPage()
            currentUrl?.let { loadUrl(it) }
        }

        rootLayout?.addView(errorPageView, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ))

        webView.visibility = View.GONE
        Logger.d(TAG, "Error page shown")
    }

    /**
     * Hide native error page
     */
    protected open fun hideErrorPage() {
        errorPageView?.visibility = View.GONE
        webView.visibility = View.VISIBLE
        Logger.d(TAG, "Error page hidden")
    }

    // ---- Bridge JS Injection ----

    protected open fun injectBridgeJavaScript() {
        val bridgeToken = if (BridgeTokenManager.enabled) BridgeTokenManager.getToken() else ""
        val signingEnabled = RequestSignatureValidator.enabled
        val sharedSecret = if (signingEnabled) RequestSignatureValidator.sharedSecret else ""

        val javascript = """
            (function() {
                if (window.__coconutInitialized) return;

                window.__coconutConfig = {
                    token: '$bridgeToken',
                    signingEnabled: $signingEnabled,
                    sharedSecret: '$sharedSecret'
                };

                if (window.Coconut && window.Coconut._loadSecurityConfig) {
                    window.Coconut._loadSecurityConfig();
                }

                window.__coconutInitialized = true;
                console.log('Coconut SDK security config injected');
            })();
        """.trimIndent()

        webView.evaluateJavascript(javascript, null)
        Logger.d(TAG, "Bridge security config injected")
    }

    // ---- Public Methods ----

    protected open fun loadUrl(url: String) {
        Logger.d(TAG, "Loading URL: $url")
        webView.loadUrl(url)
    }

    protected open fun reload() {
        currentUrl?.let {
            hideErrorPage()
            webView.reload()
        }
    }

    fun evaluateJavascript(script: String) {
        webView.evaluateJavascript(script, null)
    }

    protected fun getCurrentUrl(): String? = currentUrl

    // ---- Callbacks for subclasses ----

    protected open fun onPageFinishedCallback(url: String) {
        Logger.d(TAG, "Page finished: $url")
    }

    protected open fun onPageStartedCallback(url: String?) {
        Logger.d(TAG, "Page started: $url")
    }

    protected open fun onPageErrorCallback(url: String, error: WebResourceError?) {
        Logger.e(TAG, "Page error: $url, error: ${error?.description}")
    }

    // ---- ComponentHost implementation ----

    override fun getActivity(): Activity = this

    override fun getHostWebView(): WebView = webView

    override fun runOnMainThread(action: () -> Unit) {
        runOnUiThread(action)
    }

    // ---- Lifecycle ----

    /**
     * Whether to serve this URL from offline resources.
     * Override in subclasses to customize.
     */
    protected open fun shouldServeOffline(url: String): Boolean {
        // By default, only intercept local/coconut:// scheme or matching H5 domain resources
        return url.startsWith("file:///android_asset/coconut-web/")
    }

    /**
     * Extract resource path from URL for offline lookup
     */
    protected open fun extractResourcePath(url: String): String? {
        return when {
            url.startsWith("file:///android_asset/coconut-web/") ->
                url.removePrefix("file:///android_asset/coconut-web/")
            else -> null
        }
    }

    private fun getResourceManger(): OfflineResourceManager? {
        return try {
            CoconutResourceHolder.get(applicationContext)
        } catch (e: Exception) {
            null
        }
    }

    override fun onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack()
        } else {
            super.onBackPressed()
        }
    }

    @Deprecated("Superseded by Activity Result API, kept for component intent results.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (com.sniper.coconut.component.ActivityForResultDispatcher.dispatch(requestCode, resultCode, data)) {
            return
        }
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }

    @Deprecated("Superseded by Activity Result API, kept for component permission results.")
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (com.sniper.coconut.component.PermissionResultDispatcher.dispatch(requestCode, permissions, grantResults)) {
            return
        }
        @Suppress("DEPRECATION")
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onDestroy() {
        super.onDestroy()
        ComponentManager.getInstance().setHost(null)  // Clear host reference
        BridgeTokenManager.reset()
        Logger.d(TAG, "onDestroy")
    }
}
