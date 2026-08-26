package com.sniper.androidwebbox

import android.os.Bundle
import android.view.View
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.google.android.material.button.MaterialButton
import com.sniper.coconut.network.HttpClient
import com.sniper.coconut.network.HttpConfig
import com.sniper.coconut.network.HttpMethod
import com.sniper.coconut.network.HttpResponse
import com.sniper.coconut.network.RequestOptions
import com.sniper.coconut.utils.Logger
import kotlinx.coroutines.launch
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put

/**
 * Sniper YOLO API 冒烟（Native）— coconut-network 引擎 Kotlin 直调演示。
 *
 * 与 WebView / bridge 全链路（NetworkComponent）互补：这里验证的是
 * 引擎作为独立 JVM 库在纯 native 消费者场景下的表现（v3.4.0 架构的
 * native-first 用法，同热更新下载）。
 */
class SniperYoloAPIActivity : AppCompatActivity() {

    private val client = HttpClient(HttpConfig())
    private val prettyJson = Json { prettyPrint = true }

    private var token: String? = null
    private var createdFoodId: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_sniper_yolo_api)
        setTitle("Sniper API 冒烟")

        findViewById<MaterialButton>(R.id.btnLogin).setOnClickListener { launchStep { stepLogin() } }
        findViewById<MaterialButton>(R.id.btnListFoods).setOnClickListener { launchStep { stepListFoods() } }
        findViewById<MaterialButton>(R.id.btnCreateFood).setOnClickListener { launchStep { stepCreateFood() } }
        findViewById<MaterialButton>(R.id.btnGet404).setOnClickListener { launchStep { stepGet404() } }
        findViewById<MaterialButton>(R.id.btnDeleteFood).setOnClickListener { launchStep { stepDeleteFood() } }
        findViewById<MaterialButton>(R.id.btnRunAll).setOnClickListener { launchStep { runAll() } }
        findViewById<MaterialButton>(R.id.btnClearLog).setOnClickListener {
            findViewById<TextView>(R.id.tvSniperLog).text = ""
        }

        Logger.i(TAG, "SniperYoloAPIActivity onCreate")
    }

    // ---- 5 步冒烟（与 H5 版 net_driver 语义一致）----

    private suspend fun stepLogin(): HttpResponse? {
        val resp = exec("POST /users/test-login", "$BASE/users/test-login", RequestOptions(method = HttpMethod.POST))
        token = resp?.data?.jsonObject?.get("access_token")?.jsonPrimitive?.content
        appendLog(if (token != null) "✓ token 已保存（后续请求自动带 Bearer）" else "⚠ 未取到 access_token")
        return resp
    }

    private suspend fun stepListFoods(): HttpResponse? {
        return exec(
            "GET /foods/?count=5",
            "$BASE/foods/",
            RequestOptions(method = HttpMethod.GET, headers = authHeaders(), params = mapOf("count" to "5")),
        )
    }

    private suspend fun stepCreateFood(): HttpResponse? {
        val body = buildJsonObject {
            put("title", "native-demo-${System.currentTimeMillis()}")
            put("maker", "coconut")
            put("star", 4)
        }
        val resp = exec(
            "POST /foods/",
            "$BASE/foods/",
            RequestOptions(method = HttpMethod.POST, headers = authHeaders(), body = body),
        )
        createdFoodId = resp?.data?.jsonObject?.get("id")?.jsonPrimitive?.content
        appendLog(if (createdFoodId != null) "✓ 已记录新id=$createdFoodId（按钮5可清理）" else "⚠ 未取到新 id")
        return resp
    }

    private suspend fun stepGet404(): HttpResponse? {
        val resp = exec("GET /foods/99999", "$BASE/foods/99999", RequestOptions(method = HttpMethod.GET, headers = authHeaders()))
        appendLog(if (resp != null && !resp.isSuccess()) "✓ 404 业务失败 envelope 正常（code=${resp.code}）" else "✗ 预期业务失败，实际成功了？")
        return resp
    }

    private suspend fun stepDeleteFood(): HttpResponse? {
        val id = createdFoodId
        if (id == null) {
            appendLog("跳过：没有待清理的记录（先跑第 3 步创建）")
            return null
        }
        val resp = exec("DELETE /foods/$id", "$BASE/foods/$id", RequestOptions(method = HttpMethod.DELETE, headers = authHeaders()))
        if (resp?.isSuccess() == true) {
            createdFoodId = null
            appendLog("✓ 已清理 id=$id")
        }
        return resp
    }

    private suspend fun runAll() {
        setStepButtonsEnabled(false)
        try {
            stepLogin() ?: return
            stepListFoods() ?: return
            stepCreateFood() ?: return
            stepGet404() ?: return
            stepDeleteFood()
            appendLog("—— 全部 5 步完成 ——")
        } finally {
            setStepButtonsEnabled(true)
        }
    }

    // ---- 基础设施 ----

    /** 统一执行 + 日志渲染；网络异常返回 null（runAll 借此短路） */
    private suspend fun exec(label: String, url: String, options: RequestOptions): HttpResponse? {
        appendLog("→ $label")
        return try {
            val resp = client.request(url, options.copy(connectTimeout = TIMEOUT_MS, readTimeout = TIMEOUT_MS))
            appendLog("← HTTP ${resp.httpStatus} · code=${resp.code} · ${resp.costTime}ms")
            appendLog(pretty(resp.data ?: JsonNull))
            if (!resp.isSuccess()) appendLog("msg: ${resp.msg}")
            resp
        } catch (e: Exception) {
            appendLog("✗ 网络异常: ${e.message}")
            null
        }
    }

    private fun launchStep(block: suspend () -> Unit) {
        lifecycleScope.launch {
            try {
                block()
            } catch (e: Exception) {
                appendLog("✗ ${e.message}")
                Toast.makeText(this@SniperYoloAPIActivity, "执行失败: ${e.message}", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun authHeaders(): Map<String, String> =
        token?.let { mapOf("Authorization" to "Bearer $it") } ?: emptyMap()

    private fun setStepButtonsEnabled(enabled: Boolean) {
        listOf(R.id.btnLogin, R.id.btnListFoods, R.id.btnCreateFood, R.id.btnGet404, R.id.btnDeleteFood, R.id.btnRunAll)
            .forEach { findViewById<MaterialButton>(it).isEnabled = enabled }
    }

    private fun appendLog(line: String) {
        Logger.d(TAG, line)
        runOnUiThread {
            val tv = findViewById<TextView>(R.id.tvSniperLog)
            if (tv.text.toString() == "（日志区）") tv.text = ""
            tv.append(line + "\n\n")
            findViewById<ScrollView>(R.id.scrollSniper).post {
                findViewById<ScrollView>(R.id.scrollSniper).fullScroll(View.FOCUS_DOWN)
            }
        }
    }

    private fun pretty(el: JsonElement): String = prettyJson.encodeToString(el)

    companion object {
        private const val TAG = "SniperYoloAPI"
        private val BASE = BuildConfig.SNIPER_API_BASE
        private const val TIMEOUT_MS = 15_000
    }
}
