package com.sniper.coconut.network

import com.sniper.coconut.network.interceptors.RequestInterceptor
import com.sniper.coconut.network.utils.Logger
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.int
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class RecordingInterceptor(private val name: String, private val log: MutableList<String>) : RequestInterceptor {
    override suspend fun onRequest(request: HttpRequest): HttpRequest {
        log.add("$name:req")
        return request
    }

    override suspend fun onResponse(response: HttpResponse): HttpResponse {
        log.add("$name:resp")
        return response
    }
}

class CallTest {

    private lateinit var fake: FakeAdapter
    private lateinit var client: HttpClient

    @Before
    fun setUp() {
        // 静默引擎日志，避免测试输出噪音
        Logger.sink = { _, _, _ -> }
        fake = FakeAdapter()
        val config = HttpConfig()
        config.baseUrl = "https://api.test.com" // UrlGuard 要求完整 http/https URL
        config.retryDelay = 10 // 测试重试不等 1s
        client = HttpClient(config, fake)
    }

    @Test
    fun envelope200_parsesCodeMsgData() = runTest {
        fake.envelopeResponse(200, """{"code":"000000","msg":"ok","data":{"id":1},"timestamp":"t1"}""")
        val resp = client.newRequest("/users/1").buildCall().execute()
        assertTrue(resp.isSuccess())
        assertEquals(200, resp.httpStatus)
        assertEquals("ok", resp.msg)
        assertEquals("t1", resp.timestamp)
        assertEquals(1, resp.data!!.jsonObject["id"]!!.jsonPrimitive.int)
        // 响应头透传 + 请求 contentType 默认值
        assertEquals("application/json", resp.headers["Content-Type"])
        assertEquals("application/json", fake.requests[0].contentType)
    }

    @Test
    fun envelopeBusinessFail_codeKept_successFalse() = runTest {
        fake.envelopeResponse(200, """{"code":"500000","msg":"server busy","data":null}""")
        val resp = client.newRequest("/x").buildCall().execute()
        assertEquals(200, resp.httpStatus)
        assertFalse(resp.isSuccess())
        assertEquals("500000", resp.code)
    }

    @Test
    fun http404_returnsHttpError() = runTest {
        fake.envelopeResponse(404, """{"code":"000000","msg":"not found"}""")
        val resp = client.newRequest("/missing").buildCall().execute()
        assertFalse(resp.isSuccess())
        assertEquals(404, resp.httpStatus)
        assertEquals("404", resp.code)
        assertEquals("资源不存在", resp.msg)
    }

    @Test
    fun nonEnvelopeBody_passesThroughWithDefaultCode() = runTest {
        fake.rawResponse(200, """{"name":"manifest","version":"1.0.0"}""")
        val resp = client.newRequest("/manifest.json").buildCall().execute()
        assertTrue(resp.isSuccess())
        assertEquals("000000", resp.code)
        assertEquals("1.0.0", resp.data!!.jsonObject["version"]!!.jsonPrimitive.content)
    }

    @Test
    fun retry_failsTwiceThenSucceeds() = runTest {
        fake.envelopeResponse(200, """{"code":"000000","msg":"ok"}""")
        fake.failFirstCount = 2
        fake.failError = RuntimeException("connection reset")
        val config = client.getConfig()
        assertEquals(2, config.retryCount)
        val resp = client.newRequest("/x").buildCall().execute()
        assertTrue(resp.isSuccess())
        assertEquals(3, fake.sendCount)
    }

    @Test
    fun retryExhausted_returnsNetworkError() = runTest {
        fake.failFirstCount = 10 // 永远失败
        fake.failError = RuntimeException("connection refused")
        val resp = client.newRequest("/x").buildCall().execute()
        assertFalse(resp.isSuccess())
        assertEquals(HttpErrorCode.NETWORK_ERROR.code.toString(), resp.code)
        assertEquals(0, resp.httpStatus)
        assertEquals(3, fake.sendCount) // 1 + 2 retries
    }

    @Test
    fun timeoutError_mapsToTimeoutCode() = runTest {
        fake.failFirstCount = 10
        fake.failError = RuntimeException("Timeout after 5000ms")
        val resp = client.newRequest("/x").buildCall().execute()
        assertEquals(HttpErrorCode.TIMEOUT_ERROR.code.toString(), resp.code)
    }

    @Test
    fun headerMerge_requestOverridesConfig() = runTest {
        fake.envelopeResponse(200, """{"code":"000000"}""")
        val config = client.getConfig()
        config.headers["X-Common"] = "1"
        config.headers["X-Over"] = "config"
        client.newRequest("/x", RequestOptions(headers = mapOf("X-Over" to "req", "X-Only" to "r")))
            .buildCall().execute()
        val sent = fake.requests[0].headers
        assertEquals("1", sent["X-Common"])
        assertEquals("req", sent["X-Over"])
        assertEquals("r", sent["X-Only"])
    }

    @Test
    fun getUrlParams_encodedAndAppended() = runTest {
        fake.envelopeResponse(200, """{"code":"000000"}""")
        client.newRequest("/items", RequestOptions(params = mapOf("a" to "1", "b" to "2 3")))
            .buildCall().execute()
        assertEquals("https://api.test.com/items?a=1&b=2%203", fake.requests[0].url)
    }

    @Test
    fun urlGuardBlock_doesNotHitAdapter() = runTest {
        val config = HttpConfig() // 无 baseUrl，用绝对 URL 测守卫
        config.allowedDomains = listOf("foo.com")
        config.retryDelay = 10
        val guardClient = HttpClient(config, fake)
        val resp = guardClient.newRequest("http://evil.com/steal").buildCall().execute()
        assertFalse(resp.isSuccess())
        assertEquals(HttpErrorCode.URL_BLOCKED.code.toString(), resp.code)
        assertEquals(0, fake.sendCount)
        assertTrue(resp.msg.contains("出站守卫"))
    }

    @Test
    fun urlGuard_allowedDomain_passes() = runTest {
        fake.envelopeResponse(200, """{"code":"000000"}""")
        val config = HttpConfig() // 无 baseUrl，用绝对 URL 测守卫
        config.allowedDomains = listOf("foo.com")
        config.retryDelay = 10
        val guardClient = HttpClient(config, fake)
        val resp = guardClient.newRequest("https://api.foo.com/x").buildCall().execute()
        assertTrue(resp.isSuccess())
        assertEquals(1, fake.sendCount)
    }

    @Test
    fun interceptors_requestOrder_responseReverse() = runTest {
        fake.envelopeResponse(200, """{"code":"000000"}""")
        val log = mutableListOf<String>()
        client.addInterceptor(RecordingInterceptor("A", log))
        client.addInterceptor(RecordingInterceptor("B", log))
        client.newRequest("/x").buildCall().execute()
        assertEquals("A:req,B:req,B:resp,A:resp", log.joinToString(","))
    }

    @Test
    fun requestTimeout_overridesConfig() = runTest {
        fake.envelopeResponse(200, """{"code":"000000"}""")
        val config = client.getConfig()
        config.connectTimeout = 5000
        config.readTimeout = 6000
        client.newRequest("/x").setTimeout(111, 222).buildCall().execute()
        assertEquals(111, fake.requests[0].connectTimeout)
        assertEquals(222, fake.requests[0].readTimeout)
        // 不覆盖时走 config
        client.newRequest("/y").buildCall().execute()
        assertEquals(5000, fake.requests[1].connectTimeout)
        assertEquals(6000, fake.requests[1].readTimeout)
    }
}
