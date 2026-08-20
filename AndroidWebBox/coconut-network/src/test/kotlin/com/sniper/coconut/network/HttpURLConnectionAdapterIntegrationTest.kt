package com.sniper.coconut.network

import com.sniper.coconut.network.adapter.HttpURLConnectionAdapter
import com.sniper.coconut.network.utils.Logger
import com.sun.net.httpserver.HttpExchange
import com.sun.net.httpserver.HttpServer
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.int
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.net.InetSocketAddress

/**
 * 用 JDK 自带 HttpServer 起真 HTTP 服务的 HttpURLConnectionAdapter 集成测试
 * （覆盖下载/读写循环的真路径，纯 FakeAdapter 单测覆盖不到）
 */
class HttpURLConnectionAdapterIntegrationTest {

    private lateinit var server: HttpServer
    private lateinit var client: HttpClient

    @Before
    fun setUp() {
        Logger.sink = { _, _, _ -> }
        server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
        server.start()

        val config = HttpConfig()
        config.baseUrl = "http://127.0.0.1:${server.address.port}"
        config.retryDelay = 10
        client = HttpClient(config, HttpURLConnectionAdapter())
    }

    @After
    fun tearDown() {
        server.stop(0)
    }

    private fun respond(exchange: HttpExchange, status: Int, body: String) {
        val bytes = body.toByteArray(Charsets.UTF_8)
        exchange.responseHeaders.add("Content-Type", "application/json")
        exchange.sendResponseHeaders(status, bytes.size.toLong())
        exchange.responseBody.use { it.write(bytes) }
        exchange.close()
    }

    @Test
    fun envelope200_success() = runTest {
        server.createContext("/api/ok") { exchange ->
            respond(exchange, 200, """{"code":"000000","msg":"ok","data":{"id":1},"timestamp":"t1"}""")
        }
        val resp = client.newRequest("/api/ok").buildCall().execute()
        assertTrue(resp.isSuccess())
        assertEquals(200, resp.httpStatus)
        assertEquals("ok", resp.msg)
        assertEquals("t1", resp.timestamp)
        assertEquals(1, resp.data!!.jsonObject["id"]!!.jsonPrimitive.int)
        assertEquals("application/json", resp.headers["Content-type"] ?: resp.headers["Content-Type"])
    }

    @Test
    fun envelopeBusinessFail_codeKept() = runTest {
        server.createContext("/api/busy") { exchange ->
            respond(exchange, 200, """{"code":"500000","msg":"server busy","data":null}""")
        }
        val resp = client.newRequest("/api/busy").buildCall().execute()
        assertEquals(200, resp.httpStatus)
        assertFalse(resp.isSuccess())
        assertEquals("500000", resp.code)
    }

    @Test
    fun http501_mapsToHttpError() = runTest {
        server.createContext("/api/broken") { exchange ->
            respond(exchange, 501, """{"code":"000000","msg":"ignored"}""")
        }
        val resp = client.newRequest("/api/broken").buildCall().execute()
        assertFalse(resp.isSuccess())
        assertEquals(501, resp.httpStatus)
        assertEquals("501", resp.code)
        assertEquals("HTTP错误 501", resp.msg)
    }

    @Test
    fun nonEnvelope_jsonBody_defaultCode() = runTest {
        server.createContext("/manifest.json") { exchange ->
            respond(exchange, 200, """{"name":"manifest","version":"1.0.0"}""")
        }
        val resp = client.newRequest("/manifest.json").buildCall().execute()
        assertTrue(resp.isSuccess())
        assertEquals("000000", resp.code)
        assertEquals("1.0.0", resp.data!!.jsonObject["version"]!!.jsonPrimitive.content)
    }

    @Test
    fun queryParams_andPostBody_reachServer() = runTest {
        server.createContext("/echo") { exchange ->
            val receivedBody = if (exchange.requestMethod == "POST") {
                String(exchange.requestBody.readBytes(), Charsets.UTF_8)
            } else {
                null
            }
            val queryJson = JsonPrimitive(exchange.requestURI.rawQuery ?: "").toString()
            val bodyJson = receivedBody?.let { JsonPrimitive(it).toString() } ?: "null"
            respond(exchange, 200, """{"code":"000000","data":{"query":$queryJson,"body":$bodyJson}}""")
        }

        val getResp = client.newRequest("/echo", RequestOptions(params = mapOf("a" to "1", "b" to "2 3")))
            .buildCall().execute()
        assertTrue(getResp.isSuccess())
        assertEquals("a=1&b=2%203", getResp.data!!.jsonObject["query"]!!.jsonPrimitive.content)

        val postResp = client.newRequest("/echo", RequestOptions(method = HttpMethod.POST))
            .setBody(Json.parseToJsonElement("""{"k":"v"}"""))
            .buildCall().execute()
        assertTrue(postResp.isSuccess())
        assertEquals("""{"k":"v"}""", postResp.data!!.jsonObject["body"]!!.jsonPrimitive.content)
    }
}
