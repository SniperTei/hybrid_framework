package com.sniper.coconutandroidapp

import android.os.Bundle
import android.widget.Button
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.sniper.coconut.web.CoconutWebActivity

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContentView(R.layout.activity_main)
        ViewCompat.setOnApplyWindowInsetsListener(findViewById(R.id.main)) { v, insets ->
            val systemBars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            v.setPadding(systemBars.left, systemBars.top, systemBars.right, systemBars.bottom)
            insets
        }

        findViewById<Button>(R.id.btn_open_container).setOnClickListener {
            // H5 三件套（coconut_index.html / coconut.js / coconut.d.ts）随 app 打包
            CoconutWebActivity.start(this, "file:///android_asset/coconut_index.html", enableDebug = true)
        }

        findViewById<Button>(R.id.btn_open_h5app).setOnClickListener {
            // H5 App（真实业务试点 Phase 4）：离线包模块 h5app 由宿主 assets 自带
            // （scripts/build-offline-package.sh 分发），coconut:// 走 SDK 本地服务
            CoconutWebActivity.start(this, "coconut://h5app/index.html", enableDebug = true)
        }
    }
}
