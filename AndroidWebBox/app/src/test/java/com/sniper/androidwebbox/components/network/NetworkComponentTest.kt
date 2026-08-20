package com.sniper.androidwebbox.components.network

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import com.sniper.coconut.component.ComponentException
import com.sniper.coconut.component.ComponentManager
import com.sniper.coconut.network.HttpClient
import com.sniper.coconut.network.HttpConfig
import com.sniper.coconut.network.adapter.AdapterRequest
import com.sniper.coconut.network.adapter.AdapterResponse
import com.sniper.coconut.network.adapter.IHttpAdapter
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test

/** 测试用 Fake 传输层（coconut-network 的 test source set 不跨模块可见，此处内联一份） */
private class FakeAdapter : IHttpAdapter {
    val requests = mutableListOf<AdapterRequest>()
    var response: AdapterResponse = AdapterResponse(200, emptyMap(), null)

    override suspend fun sendRequest(request: AdapterRequest): AdapterResponse {
        requests.add(request)
        return response
    }

    fun respond(httpStatus: Int, bodyJson: String) {
        response = AdapterResponse(
            httpStatus,
            mapOf("Content-Type" to "application/json"),
            Json.parseToJsonElement(bodyJson),
        )
    }
}

class NetworkComponentTest {

    private lateinit var fake: FakeAdapter
    private lateinit var component: NetworkComponent

    companion object {
        // 共享 mock context：ComponentManager.sharedContext 是 lazy 单例（JUnit 每个测试方法
        // 新建测试类实例），必须所有测试共用同一个 mock 才能命中 stub
        private val mockContext: Context = mockk(relaxed = true)
    }

    @Before
    fun setUp() {
        fake = FakeAdapter()
        val config = HttpConfig()
        config.retryDelay = 10
        component = NetworkComponent(HttpClient(config, fake))

        ComponentManager.getInstance().apply {
            setApplicationContext(mockContext)
            setCoroutineScope(CoroutineScope(SupervisorJob()))
        }
    }

    @After
    fun tearDown() = kotlinx.coroutines.runBlocking {
        try {
            ComponentManager.getInstance().unregister("network")
        } catch (e: Exception) {
            // 未注册时静默
        }
    }

    private suspend fun register(): NetworkComponent {
        ComponentManager.getInstance().register(component)
        return component
    }

    private fun requestParams(vararg pairs: Pair<String, JsonElement>): kotlinx.serialization.json.JsonObject? =
        buildJsonObject {
            for ((k, v) in pairs) put(k, v)
        }

    @Test
    fun request_happyPath_fields() = runTest {
        fake.respond(200, """{"code":"000000","msg":"ok","data":{"id":1}}""")
        register()

        val result = component.handle(
            "request",
            requestParams(
                "url" to Json.parseToJsonElement("\"https://api.foo.com/users/1\""),
            ),
        )

        assertEquals(1, fake.requests.size)
        assertEquals("https://api.foo.com/users/1", fake.requests[0].url)
        assertEquals("GET", fake.requests[0].method)

        val obj = result.jsonObject
        assertTrue(obj["success"]!!.jsonPrimitive.boolean)
        assertEquals("000000", obj["code"]!!.jsonPrimitive.content)
        assertEquals(200, obj["httpStatus"]!!.jsonPrimitive.content.toInt())
        assertEquals("ok", obj["msg"]!!.jsonPrimitive.content)
        assertEquals("ok", obj["message"]!!.jsonPrimitive.content)
        assertEquals(1, obj["data"]!!.jsonObject["id"]!!.jsonPrimitive.content.toInt())
        assertTrue(obj.containsKey("costTime"))
        assertTrue(obj.containsKey("headers"))
    }

    @Test
    fun request_headersBodyParams_reachEngine() = runTest {
        fake.respond(200, """{"code":"000000"}""")
        register()

        component.handle(
            "request",
            requestParams(
                "url" to Json.parseToJsonElement("\"https://api.foo.com/echo\""),
                "method" to Json.parseToJsonElement("\"POST\""),
                "headers" to buildJsonObject { put("X-A", "1") },
                "body" to buildJsonObject { put("k", "v") },
                "timeoutMs" to Json.parseToJsonElement("1234"),
            ),
        )

        val sent = fake.requests[0]
        assertEquals("POST", sent.method)
        assertEquals("1", sent.headers["X-A"])
        assertEquals(1234, sent.connectTimeout)
        assertEquals(1234, sent.readTimeout)
        assertEquals("v", sent.body!!.jsonObject["k"]!!.jsonPrimitive.content)
    }

    @Test
    fun request_guardBlocked_mapsTo200007() = runTest {
        register()
        // 默认 config.allowedDomains 为空 → 放行；构造白名单场景由引擎保证，
        // 此处验证组件层映射：直接用被守卫拦截的响应路径不可行（引擎在 guard 时不落 adapter），
        // 故通过白名单 + 非 http scheme 触发
        try {
            component.handle(
                "request",
                requestParams(
                    "url" to Json.parseToJsonElement("\"coconut://demo/index.html\""),
                ),
            )
            fail("expected ComponentException")
        } catch (e: ComponentException) {
            assertEquals("200007", e.code)
            assertTrue(e.message!!.contains("出站守卫"))
        }
        assertEquals(0, fake.requests.size)
    }

    @Test
    fun request_methodNotAllowed_mapsTo200007() = runTest {
        register()
        try {
            component.handle(
                "request",
                requestParams(
                    "url" to Json.parseToJsonElement("\"https://api.foo.com/x\""),
                    "method" to Json.parseToJsonElement("\"PATCH\""),
                ),
            )
            fail("expected ComponentException")
        } catch (e: ComponentException) {
            assertEquals("200007", e.code)
            assertTrue(e.message!!.contains("PATCH"))
        }
    }

    @Test
    fun request_missingUrl_mapsTo200007() = runTest {
        register()
        try {
            component.handle("request", requestParams())
            fail("expected ComponentException")
        } catch (e: ComponentException) {
            assertEquals("200007", e.code)
        }
    }

    @Test
    fun request_http501_successFalse_businessCodeKept() = runTest {
        fake.respond(501, """{"code":"000000"}""")
        register()

        val result = component.handle(
            "request",
            requestParams("url" to Json.parseToJsonElement("\"https://api.foo.com/broken\"")),
        )

        val obj = result.jsonObject
        assertFalse(obj["success"]!!.jsonPrimitive.boolean)
        assertEquals(501, obj["httpStatus"]!!.jsonPrimitive.content.toInt())
        assertEquals("501", obj["code"]!!.jsonPrimitive.content)
    }

    @Test
    fun getNetworkType_shape_wifi() = runTest {
        val cm = mockk<ConnectivityManager>()
        val network = mockk<Network>()
        val caps = mockk<NetworkCapabilities>()
        every { mockContext.getSystemService(Context.CONNECTIVITY_SERVICE) } returns cm
        every { cm.activeNetwork } returns network
        every { cm.getNetworkCapabilities(network) } returns caps
        every { caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) } returns true
        every { caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) } returns false
        every { caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) } returns false
        register()

        val result = component.handle("getNetworkType", null)
        val obj = result.jsonObject
        assertEquals("wifi", obj["type"]!!.jsonPrimitive.content)
        assertTrue(obj["online"]!!.jsonPrimitive.boolean)
        assertTrue(obj["success"]!!.jsonPrimitive.boolean)
    }

    @Test
    fun getNetworkType_noActiveNetwork_none() = runTest {
        val cm = mockk<ConnectivityManager>()
        every { mockContext.getSystemService(Context.CONNECTIVITY_SERVICE) } returns cm
        every { cm.activeNetwork } returns null
        register()

        val result = component.handle("getNetworkType", null)
        val obj = result.jsonObject
        assertEquals("none", obj["type"]!!.jsonPrimitive.content)
        assertFalse(obj["online"]!!.jsonPrimitive.boolean)
    }

    @Test
    fun networkChange_emit_deduped() = runTest {
        register()

        val scripts = mutableListOf<String>()
        val emitter = ComponentManager.getInstance().eventEmitter
        emitter.jsExecutor = { scripts.add(it) }
        emitter.on(NETWORK_TOPIC_CHANGE)

        component.emitState("wifi", true)
        component.emitState("wifi", true)  // 重复 → 去重
        component.emitState("none", false)

        assertEquals(2, scripts.size)
        assertTrue(scripts[0].contains("network.change"))
        assertTrue(scripts[0].contains("wifi"))
        assertTrue(scripts[1].contains("none"))

        emitter.clearAll()
        emitter.jsExecutor = null
    }

    @Test
    fun unknownFunction_throws() = runTest {
        register()
        try {
            component.handle("nope", null)
            fail("expected ComponentException")
        } catch (e: ComponentException) {
            assertTrue(e.message!!.contains("not supported"))
        }
    }
}
