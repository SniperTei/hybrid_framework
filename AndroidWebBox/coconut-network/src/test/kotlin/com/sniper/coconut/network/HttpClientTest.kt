package com.sniper.coconut.network

import com.sniper.coconut.network.adapter.HttpResponseType
import com.sniper.coconut.network.utils.Logger
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * 一发式便利 API + bytes 模式（对齐 Harmony @coconut/network v1.1.0 HttpClient.test.ets）
 */
class HttpClientTest {

    private lateinit var fake: FakeAdapter
    private lateinit var client: HttpClient

    @Before
    fun setUp() {
        Logger.sink = { _, _, _ -> }
        fake = FakeAdapter()
        val config = HttpConfig()
        config.baseUrl = "https://api.test.com"
        config.retryDelay = 10
        client = HttpClient(config, fake)
    }

    @Test
    fun oneShotGet_envelope200() = runTest {
        fake.envelopeResponse(200, """{"code":"000000","msg":"ok","data":{"id":7}}""")
        val resp = client.get("/users/1")
        assertTrue(resp.isSuccess())
        assertEquals("GET", fake.requests[0].method)
        assertEquals(7, resp.data!!.jsonObject["id"]!!.jsonPrimitive.content.toInt())
    }

    @Test
    fun oneShotPost_bodyDelivered() = runTest {
        fake.envelopeResponse(200, """{"code":"000000","msg":"ok","data":null}""")
        val resp = client.post("/users", JsonPrimitive("payload"))
        assertTrue(resp.isSuccess())
        assertEquals("POST", fake.requests[0].method)
        assertEquals("\"payload\"", fake.requests[0].body.toString())
    }

    @Test
    fun oneShotPutDelete_methods() = runTest {
        client.put("/users/1", JsonPrimitive("u"))
        assertEquals("PUT", fake.requests[0].method)
        client.delete("/users/1")
        assertEquals("DELETE", fake.requests[1].method)
    }

    @Test
    fun oneShotGet_paramsBecomeQuery() = runTest {
        fake.envelopeResponse(200, """{"code":"000000"}""")
        client.get("/search", RequestOptions(params = mapOf("q" to "coconut")))
        val url = fake.requests[0].url
        assertTrue(url.startsWith("https://api.test.com/search?"))
        assertTrue(url.contains("q=coconut"))
    }

    @Test
    fun oneShotGet_timeoutOverride() = runTest {
        fake.envelopeResponse(200, """{"code":"000000"}""")
        client.get("/slow", RequestOptions(connectTimeout = 5000, readTimeout = 9000))
        assertEquals(5000, fake.requests[0].connectTimeout)
        assertEquals(9000, fake.requests[0].readTimeout)
    }

    @Test
    fun bytes200_rawDataPassthrough() = runTest {
        val payload = byteArrayOf(1, 2, 3, 4, 5)
        fake.bytesResponse(200, payload)
        val resp = client.get("/file.bin", RequestOptions(responseType = HttpResponseType.BYTES))

        assertTrue(resp.isSuccess())
        assertEquals("000000", resp.code)
        assertArrayEquals(payload, resp.rawData)
        assertNull(resp.data)
    }

    @Test
    fun bytes404_httpError() = runTest {
        fake.bytesResponse(404, byteArrayOf(0))
        val resp = client.get("/missing.bin", RequestOptions(responseType = HttpResponseType.BYTES))

        assertFalse(resp.isSuccess())
        assertEquals("404", resp.code)
        assertEquals("资源不存在", resp.msg)
    }

    @Test
    fun bytesNonEnvelopeNoSniffing() = runTest {
        // bytes 内容恰为 envelope 形状的 JSON 也不进 envelope 分支（无嗅探）
        val envelopeBytes = """{"code":"000000","msg":"ok","data":{"id":1}}""".toByteArray()
        fake.bytesResponse(200, envelopeBytes)
        val resp = client.get("/manifest.json", RequestOptions(responseType = HttpResponseType.BYTES))

        assertTrue(resp.isSuccess())
        assertArrayEquals(envelopeBytes, resp.rawData)
        assertNull(resp.data)
    }

    @Test
    fun bytesAdapterRequestCarriesResponseType() = runTest {
        fake.bytesResponse(200, byteArrayOf(9))
        client.get("/blob", RequestOptions(responseType = HttpResponseType.BYTES))
        assertEquals(HttpResponseType.BYTES, fake.requests[0].responseType)

        fake.envelopeResponse(200, """{"code":"000000"}""")
        client.get("/api")
        assertEquals(HttpResponseType.JSON, fake.requests[1].responseType)
    }

    @Test
    fun mockShortCircuit_bytesRequest_rawDataNull() = runTest {
        // 已知限制钉死：mock 短路不感知 responseType —— bytes 请求命中 mock
        // 返回 object data、rawData=null（Harmony 引擎同样限制）
        fake.envelopeResponse(200, """{"code":"000000"}""")
        val resp = client.newRequest("/mocked.bin", RequestOptions(responseType = HttpResponseType.BYTES))
            .enableMocking(JsonPrimitive("mock-data"))
            .buildCall()
            .execute()

        assertTrue(resp.isSuccess())
        assertEquals(0, fake.sendCount) // 未落 adapter
        assertNull(resp.rawData)
        assertEquals("\"mock-data\"", resp.data.toString())
    }
}
