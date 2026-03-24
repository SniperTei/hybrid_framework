package com.sniper.webbox

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.widget.Toast
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.sniper.hybrid.HybridConfig
import com.sniper.hybrid.core.WebContainer
import com.sniper.hybrid.plugins.*
import okhttp3.Interceptor
import okhttp3.Response
import java.io.IOException

class MainActivity : AppCompatActivity() {

    private lateinit var webContainer: WebContainer

    // 权限请求启动器
    private val requestPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        val allGranted = permissions.values.all { it }
        if (!allGranted) {
            Toast.makeText(this, "部分权限未授予，某些功能可能无法使用", Toast.LENGTH_LONG).show()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContentView(R.layout.activity_main)
        ViewCompat.setOnApplyWindowInsetsListener(findViewById(R.id.main)) { v, insets ->
            val systemBars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            v.setPadding(systemBars.left, systemBars.top, systemBars.right, systemBars.bottom)
            insets
        }

        // 初始化WebContainer
        initWebContainer()

        // 设置返回键处理
        setupBackPressedCallback()

        // 请求运行时权限
        requestRuntimePermissions()
    }

    private fun setupBackPressedCallback() {
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                if (webContainer.canGoBack()) {
                    webContainer.goBack()
                } else {
                    isEnabled = false
                    onBackPressedDispatcher.onBackPressed()
                }
            }
        })
    }

    private fun initWebContainer() {
        // 创建WebContainer
        webContainer = WebContainer(this)

        // 创建Hybrid配置
        val config = HybridConfig.Builder()
            .setDefaultUrl("file:///android_asset/index.html")
            .setDebugMode(true) // 开发阶段开启调试
            .setEnableCache(true)
            .setEnableDomStorage(true)
            .setAllowFileAccess(true)
            .build()

        // 初始化WebContainer
        webContainer.init(config, this)

        // 注册插件
        registerPlugins()

        // 设置主视图
        setContentView(webContainer)

        // 加载URL
        webContainer.loadHybridUrl(config.defaultUrl)
    }

    private fun registerPlugins() {
        val pluginManager = webContainer.getPluginManager() ?: return

        // 创建网络插件并配置
        val networkPlugin = NetworkPlugin()

        // 创建网络配置
        val networkConfig = com.sniper.hybrid.plugins.NetworkConfig.Builder()
            .setBaseUrl("https://api.example.com") // 替换为你的API地址
            .setConnectTimeout(30_000)
            .setReadTimeout(30_000)
            .setEnableCache(true)
            .setRetryCount(2)
            // 添加通用请求头
            .setDefaultHeaders(mapOf(
                "Content-Type" to "application/json",
                "Accept" to "application/json"
            ))
            // 添加请求拦截器（例如：添加token）
            .addRequestInterceptor(Interceptor { chain ->
                val originalRequest = chain.request()
                // 这里可以添加认证token等
                val requestBuilder = originalRequest.newBuilder()
                    .header("X-App-Version", "1.0.0")
                    .header("X-Platform", "Android")

                // 示例：如果有token，添加到请求头
                // val token = getAuthToken()
                // if (token.isNotEmpty()) {
                //     requestBuilder.header("Authorization", "Bearer $token")
                // }

                chain.proceed(requestBuilder.build())
            })
            // 添加响应拦截器（例如：统一错误处理）
            .addResponseInterceptor(Interceptor { chain ->
                val response = chain.proceed(chain.request())
                // 可以在这里处理统一的错误码
                if (response.code == 401) {
                    // Token过期，需要重新登录
                    runOnUiThread {
                        Toast.makeText(this@MainActivity, "登录已过期，请重新登录", Toast.LENGTH_SHORT).show()
                    }
                }
                response
            })
            .build()

        networkPlugin.setConfig(networkConfig)

        // 注册内置插件
        pluginManager.registerPlugins(listOf(
            CameraPlugin(),
            GalleryPlugin(),
            VideoPlugin(),
            DevicePlugin(),
            networkPlugin
        ))

        // 可以继续添加更多插件...
    }

    // 示例：获取认证token的方法
    private fun getAuthToken(): String {
        val prefs = getSharedPreferences("app_prefs", MODE_PRIVATE)
        return prefs.getString("auth_token", "") ?: ""
    }

    private fun requestRuntimePermissions() {
        val permissionsToRequest = mutableListOf<String>()

        // 相机权限
        if (checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            permissionsToRequest.add(Manifest.permission.CAMERA)
        }

        // 录音权限
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            permissionsToRequest.add(Manifest.permission.RECORD_AUDIO)
        }

        // Android 13+媒体权限
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(Manifest.permission.READ_MEDIA_IMAGES) != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(Manifest.permission.READ_MEDIA_IMAGES)
            }
            if (checkSelfPermission(Manifest.permission.READ_MEDIA_VIDEO) != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(Manifest.permission.READ_MEDIA_VIDEO)
            }
        } else {
            // Android 12及以下
            if (checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(Manifest.permission.READ_EXTERNAL_STORAGE)
            }
        }

        if (permissionsToRequest.isNotEmpty()) {
            requestPermissionLauncher.launch(permissionsToRequest.toTypedArray())
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        webContainer.onActivityResult(requestCode, resultCode, data)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        webContainer.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onDestroy() {
        webContainer.cleanup()
        super.onDestroy()
    }
}