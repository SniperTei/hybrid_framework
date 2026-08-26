package com.sniper.androidwebbox

import android.os.Bundle
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.google.android.material.button.MaterialButton
import com.google.android.material.textfield.TextInputEditText
import com.sniper.coconut.CoconutSDK
import com.sniper.coconut.resource.CoconutResourceHolder
import com.sniper.coconut.web.CoconutWebActivity
import com.sniper.coconut.utils.Logger
import kotlinx.coroutines.launch

/**
 * MainActivity - Coconut SDK Demo App
 *
 * Shows how to use CoconutWebActivity with environment-aware URLs.
 */
class MainActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        Logger.i("MainActivity", "Activity onCreate")
        setupViews()
    }

    private fun setupViews() {
        findViewById<MaterialButton>(R.id.btnOpenWebView).setOnClickListener {
            openCoconutWebView()
        }

        findViewById<MaterialButton>(R.id.btnOpenLocal).setOnClickListener {
            openLocalTestPage()
        }

        findViewById<MaterialButton>(R.id.btnOpenOfflinePackage).setOnClickListener {
            openOfflinePackage()
        }

        findViewById<MaterialButton>(R.id.btnSniperSmoke).setOnClickListener {
            Logger.d("MainActivity", "Opening Sniper YOLO API native smoke")
            startActivity(android.content.Intent(this, SniperYoloAPIActivity::class.java))
        }

        findViewById<MaterialButton>(R.id.btnCheckUpdate).setOnClickListener {
            checkHotUpdate()
        }

        findViewById<MaterialButton>(R.id.btnRollback).setOnClickListener {
            rollbackHotUpdate()
        }

        Logger.d("MainActivity", "Views setup complete")
    }

    /**
     * Open Coconut WebView with environment-aware URL
     */
    private fun openCoconutWebView() {
        val config = CoconutSDK.getConfig()
        val envUrl = config.effectiveH5Domain

        Logger.d("MainActivity", "Opening Coconut WebView: $envUrl (env: ${config.environment.displayName})")

        CoconutWebActivity.start(this, envUrl, enableDebug = true)
        Toast.makeText(this, "Opening ${config.environment.displayName} environment...", Toast.LENGTH_SHORT).show()
    }

    private fun openLocalTestPage() {
        val url = "file:///android_asset/coconut_index.html"
        Logger.d("MainActivity", "Opening local test page: $url")
        CoconutWebActivity.start(this, url)
        Toast.makeText(this, "Opening local test page...", Toast.LENGTH_SHORT).show()
    }

    /**
     * Open H5 from the bundled offline package (coconut:// scheme)
     */
    private fun openOfflinePackage() {
        val url = "coconut://demo/index.html"
        Logger.d("MainActivity", "Opening offline package: $url")
        CoconutWebActivity.start(this, url)
        Toast.makeText(this, "Opening offline package...", Toast.LENGTH_SHORT).show()
    }

    /**
     * Check for a hot update; if available, download + apply it automatically.
     */
    private fun checkHotUpdate() {
        val manifestUrl = findViewById<TextInputEditText>(R.id.etManifestUrl).text?.toString()?.trim().orEmpty()
        if (manifestUrl.isEmpty()) {
            Toast.makeText(this, "Manifest URL is empty", Toast.LENGTH_SHORT).show()
            return
        }
        val manager = CoconutResourceHolder.get(this)
        Toast.makeText(this, "Checking update...", Toast.LENGTH_SHORT).show()
        lifecycleScope.launch {
            val check = manager.checkUpdate("demo", manifestUrl)
            when {
                check.error != null -> {
                    Logger.e("MainActivity", "checkUpdate failed: ${check.error}")
                    runOnUiThread { toastLong("Check failed: ${check.error}") }
                }
                !check.available -> {
                    runOnUiThread { toastLong("No update (current ${check.currentVersion})") }
                }
                else -> {
                    val result = manager.performUpdate(check.manifest!!, manifestUrl.substringBeforeLast('/') )
                    if (result.success) {
                        runOnUiThread { toastLong("Updated: ${check.currentVersion} → ${result.version}") }
                    } else {
                        runOnUiThread { toastLong("Update failed: ${result.error}") }
                    }
                }
            }
        }
    }

    /**
     * Roll the demo module back to the bundled offline package.
     */
    private fun rollbackHotUpdate() {
        val manager = CoconutResourceHolder.get(this)
        lifecycleScope.launch {
            val ok = manager.rollback("demo")
            runOnUiThread {
                if (ok) {
                    toastLong("Rolled back to bundled v${manager.getLocalVersion("demo")}")
                } else {
                    toastLong("Rollback failed")
                }
            }
        }
    }

    private fun toastLong(msg: String) {
        Toast.makeText(this, msg, Toast.LENGTH_LONG).show()
    }

    override fun onDestroy() {
        super.onDestroy()
        Logger.d("MainActivity", "Activity destroyed")
    }
}
