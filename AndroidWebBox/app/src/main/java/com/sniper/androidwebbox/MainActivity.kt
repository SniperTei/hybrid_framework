package com.sniper.androidwebbox

import android.os.Bundle
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.button.MaterialButton
import com.sniper.coconut.CoconutSDK
import com.sniper.coconut.web.CoconutWebActivity
import com.sniper.coconut.utils.Logger

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

    override fun onDestroy() {
        super.onDestroy()
        Logger.d("MainActivity", "Activity destroyed")
    }
}
