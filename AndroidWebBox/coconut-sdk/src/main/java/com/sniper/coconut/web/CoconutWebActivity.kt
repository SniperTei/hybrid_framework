package com.sniper.coconut.web

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
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
import org.json.JSONArray
import org.json.JSONObject
import androidx.appcompat.widget.Toolbar
import com.sniper.coconut.CoconutSDK
import com.sniper.coconut.bridge.CoconutBridgeImpl
import com.sniper.coconut.bridge.BridgeTokenManager
import com.sniper.coconut.component.ComponentHost
import com.sniper.coconut.component.ComponentManager
import com.sniper.coconut.nav.NavConfig
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
        /** Offline-package virtual host. HTTPS so requests reliably flow
         *  through shouldInterceptRequest (file: does not). The host is
         *  fictional and only meaningful inside interception. */
        private const val OFFLINE_HOST_PREFIX = "https://coconut.local/coconut-web/"
        private const val EXTRA_URL = "extra_url"
        private const val EXTRA_ENABLE_DEBUG = "extra_enable_debug"
        private const val EXTRA_USER_AGENT = "extra_user_agent"
        private const val EXTRA_TITLE_BAR_VISIBLE = "extra_title_bar_visible"
        private const val EXTRA_TITLE_TEXT = "extra_title_text"
        /** Per-open NavConfig override JSON (forward header / native callers) */
        private const val EXTRA_NAV_JSON = "extra_nav_json"

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
    private var rightActionButton: TextView? = null
    private var closeButton: TextView? = null

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

    // ---- Navigation bar config (resolved in onCreate before setupUI) ----
    private var navConfig: NavConfig = NavConfig.default()

    /**
     * Template-subclass code-level NavConfig default (second tier of the
     * three-tier chain: CoconutConfig.nav < this < per-open extras/header).
     * All-null by default → pure inherit. Override in subclasses:
     * `override val defaultNavConfig = NavConfig(titleMode = NavConfig.TitleMode.FIXED, titleText = "模板页")`
     */
    protected open val defaultNavConfig: NavConfig = NavConfig()

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

        // Resolve navigation-bar config (must precede setupUI)
        resolveNavConfig()

        // Setup UI and WebView
        setupUI()
        ComponentManager.getInstance().setHost(this)  // Set this Activity as component host
        setupWebView()
        setupBridge()
        loadUrl(url)
    }

    /**
     * Resolve the effective NavConfig for this container instance:
     * CoconutConfig.nav (global) ← defaultNavConfig (template subclass)
     * ← legacy title-bar extras ← EXTRA_NAV_JSON (forward header / native caller).
     * Field-by-field, null = inherit.
     */
    private fun resolveNavConfig() {
        var cfg = if (CoconutSDK.isInitialized()) CoconutSDK.getConfig().nav.copy() else NavConfig.default()
        cfg = NavConfig.merge(cfg, defaultNavConfig)

        // Legacy extras compatibility
        val legacy = NavConfig(
            visible = if (intent.hasExtra(EXTRA_TITLE_BAR_VISIBLE)) titleBarVisible else null,
            titleMode = if (titleText != null) NavConfig.TitleMode.FIXED else null,
            titleText = titleText,
        )
        cfg = NavConfig.merge(cfg, legacy)

        intent.getStringExtra(EXTRA_NAV_JSON)?.let { json ->
            NavConfig.parseOverride(json)?.let { cfg = NavConfig.merge(cfg, it) }
        }
        navConfig = cfg
        Logger.d(TAG, "NavConfig resolved: visible=${navConfig.visible}, titleMode=${navConfig.titleMode}, closePolicy=${navConfig.closePolicy}")
    }

    /**
     * Setup the root UI layout with optional toolbar and progress bar
     */
    protected open fun setupUI() {
        rootLayout = FrameLayout(this).apply {
            setBackgroundColor(Color.WHITE)
        }

        // Title bar
        if (navConfig.visible == true) {
            toolbar = Toolbar(this).apply {
                setBackgroundColor(Color.parseColor("#FFFFFF"))
                setTitleTextColor(Color.parseColor("#333333"))
                if (navConfig.titleMode == NavConfig.TitleMode.FIXED) {
                    title = navConfig.titleText ?: ""
                }
                setNavigationIcon(androidx.appcompat.R.drawable.abc_ic_ab_back_material)
                setNavigationOnClickListener { onNavBack() }
            }

            // Left custom text button replaces the back icon
            navConfig.leftButtonText?.let { text ->
                toolbar?.navigationIcon = null
                val btn = makeNavTextButton(text)
                btn.setOnClickListener { onLeftNavButtonTap() }
                toolbar?.addView(btn, Toolbar.LayoutParams(
                    Toolbar.LayoutParams.WRAP_CONTENT,
                    Toolbar.LayoutParams.WRAP_CONTENT
                ).apply { gravity = Gravity.START })
            }
            updateRightNavButtons()
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

        // Chrome client: title sync for AUTO nav mode
        webView.webChromeClient = object : android.webkit.WebChromeClient() {
            override fun onReceivedTitle(view: WebView?, title: String?) {
                super.onReceivedTitle(view, title)
                // AUTO mode syncs document.title into the toolbar;
                // FIXED keeps whatever the config resolved.
                if (navConfig.titleMode != NavConfig.TitleMode.FIXED) {
                    toolbar?.title = title ?: ""
                }
            }
        }

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
                // Clear stale H5 event subscriptions so reload doesn't deliver
                // events registered by the previous page context.
                ComponentManager.getInstance().eventEmitter.clearAll()
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

            override fun doUpdateVisitedHistory(view: WebView?, url: String?, isReload: Boolean) {
                super.doUpdateVisitedHistory(view, url, isReload)
                // Close-button visibility depends on canGoBack state
                updateRightNavButtons()
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

        // Wire EventEmitter → WebView. Native emit() may come from background
        // threads (e.g. ConnectivityManager), so hop to UI thread before
        // evaluateJavascript.
        ComponentManager.getInstance().eventEmitter.jsExecutor = { script ->
            runOnMainThread {
                if (::webView.isInitialized) {
                    webView.evaluateJavascript(script, null)
                }
            }
        }

        Logger.d(TAG, "Bridge setup complete")
    }

    // ---- Navigation bar ----

    /**
     * Unified back semantics: H5 history first, degrade to closing the
     * container. Navigation bar back button, physical back and
     * coconut.navigator.back() all route through here.
     */
    protected open fun onNavBack() {
        if (::webView.isInitialized && webView.canGoBack()) {
            webView.goBack()
        } else {
            finish()
        }
    }

    /**
     * Left custom text button tap. Default = standard back semantics;
     * overridden in v3.5.0 to check for a "nav.button" H5 subscription first.
     */
    protected open fun onLeftNavButtonTap() {
        onNavBack()
    }

    /**
     * Right custom action button tap. No default action (the × close button
     * is a separate control); v3.5.0 emits "nav.button" to subscribed H5.
     */
    protected open fun onRightNavButtonTap() {
        Logger.w(TAG, "Right nav button tapped with no subscription — no-op")
    }

    private fun makeNavTextButton(text: String): TextView {
        return TextView(this).apply {
            this.text = text
            setTextColor(Color.parseColor("#333333"))
            textSize = 16f
            gravity = Gravity.CENTER
            val pad = (resources.displayMetrics.density * 12).toInt()
            setPadding(pad, 0, pad, 0)
        }
    }

    /**
     * Recompute the toolbar right side: custom action button when configured,
     * otherwise × close button when [NavConfig.shouldShowClose] says so.
     * Called on history changes (doUpdateVisitedHistory).
     */
    protected open fun updateRightNavButtons() {
        val tb = toolbar ?: return
        rightActionButton?.let { tb.removeView(it) }
        rightActionButton = null
        closeButton?.let { tb.removeView(it) }
        closeButton = null

        val canGoBack = if (::webView.isInitialized && !webView.url.isNullOrEmpty()) {
            webView.canGoBack()
        } else {
            false
        }

        val rightText = navConfig.rightButtonText
        if (rightText != null) {
            rightActionButton = makeNavTextButton(rightText).apply {
                setOnClickListener { onRightNavButtonTap() }
            }
            tb.addView(rightActionButton, Toolbar.LayoutParams(
                Toolbar.LayoutParams.WRAP_CONTENT,
                Toolbar.LayoutParams.WRAP_CONTENT
            ).apply { gravity = Gravity.END })
        } else if (navConfig.shouldShowClose(canGoBack)) {
            closeButton = makeNavTextButton("✕").apply {
                setOnClickListener { finish() }
            }
            tb.addView(closeButton, Toolbar.LayoutParams(
                Toolbar.LayoutParams.WRAP_CONTENT,
                Toolbar.LayoutParams.WRAP_CONTENT
            ).apply { gravity = Gravity.END })
        }
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

        val (appName, appVersion) = try {
            val pm = packageManager
            val pkg = pm.getPackageInfo(packageName, 0)
            val label = try {
                pm.getApplicationLabel(pkg.applicationInfo).toString()
            } catch (e: Exception) {
                packageName
            }
            label to (pkg.versionName ?: "")
        } catch (e: PackageManager.NameNotFoundException) {
            packageName to ""
        }

        val config = JSONObject().apply {
            put("token", bridgeToken)
            put("appName", appName)
            put("appVersion", appVersion)
            put("hybridVersion", "3")
            // Capabilities: {componentName: [method names]} — H5 reads via
            // coconut.env.capabilities / coconut.supports(component, fn).
            val capabilities = JSONObject()
            ComponentManager.getInstance().getCapabilities().forEach { (name, methods) ->
                capabilities.put(name, JSONArray(methods))
            }
            put("capabilities", capabilities)
        }

        val javascript = """
            (function() {
                if (window.__coconutInitialized) return;

                window.__coconutConfig = $config;

                if (window.coconut && window.coconut._loadSecurityConfig) {
                    window.coconut._loadSecurityConfig();
                }

                window.__coconutInitialized = true;
                console.log('Coconut SDK config injected');
            })();
        """.trimIndent()

        webView.evaluateJavascript(javascript, null)
        Logger.d(TAG, "Bridge config injected: appName=$appName, appVersion=$appVersion")
    }

    // ---- Public Methods ----

    protected open fun loadUrl(url: String) {
        val translated = translateOfflineUrl(url)
        Logger.d(TAG, "Loading URL: $url -> $translated")
        currentUrl = translated
        webView.loadUrl(translated)
    }

    /**
     * Translate coconut:// offline package URLs into a virtual-host https URL.
     * shouldInterceptRequest is NOT called for file: scheme requests (long-
     * standing Chromium behavior, issues.chromium.org/issues/40419811), so a
     * file:///android_asset translation would silently skip the sandbox
     * overlay. An https virtual host flows through interception reliably,
     * where OfflineResourceManager serves sandbox > assets.
     *
     *   coconut://demo/index.html
     *     -> https://coconut.local/coconut-web/demo/index.html
     */
    protected open fun translateOfflineUrl(url: String): String {
        if (!url.startsWith("coconut://")) return url
        val path = url.removePrefix("coconut://").trimStart('/')
        return "https://coconut.local/coconut-web/$path"
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
        // Offline virtual host (see translateOfflineUrl); file: requests never
        // reach shouldInterceptRequest, so only the https prefix matters here.
        return url.startsWith(OFFLINE_HOST_PREFIX)
    }

    /**
     * Extract resource path from URL for offline lookup
     */
    protected open fun extractResourcePath(url: String): String? {
        return when {
            url.startsWith(OFFLINE_HOST_PREFIX) ->
                url.removePrefix(OFFLINE_HOST_PREFIX)
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
        // Same semantics as the navigation bar back button (single path)
        onNavBack()
    }

    override fun onDestroy() {
        super.onDestroy()
        ComponentManager.getInstance().setHost(null)  // Clear host reference
        BridgeTokenManager.reset()
        Logger.d(TAG, "onDestroy")
    }
}
