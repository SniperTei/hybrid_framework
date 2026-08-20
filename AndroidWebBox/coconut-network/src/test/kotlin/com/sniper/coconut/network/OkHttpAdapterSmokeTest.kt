package com.sniper.coconut.network

import com.sniper.coconut.network.adapter.OkHttpAdapter
import com.sniper.coconut.network.utils.Logger
import com.sun.net.httpserver.HttpExchange
import com.sun.net.httpserver.HttpServer
import kotlinx.coroutines.test.runTest
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

/** OkHttpAdapter 冒烟：走真 HTTP 服务的最小路径（详细行为由 HttpURLConnection 集成测试覆盖） */
class OkHttpAdapterSmokeTest {

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
        client = HttpClient(config, OkHttpAdapter())
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
            respond(exchange, 200, """{"code":"000000","msg":"ok","data":{"id":7}}""")
        }
        val resp = client.newRequest("/api/ok").buildCall().execute()
        assertTrue(resp.isSuccess())
        assertEquals(200, resp.httpStatus)
        assertEquals(7, resp.data!!.jsonObject["id"]!!.jsonPrimitive.int)
    }

    @Test
    fun http501_mapsToHttpError() = runTest {
        server.createContext("/api/broken") { exchange ->
            respond(exchange, 501, """{"code":"000000"}""")
        }
        val resp = client.newRequest("/api/broken").buildCall().execute()
        assertFalse(resp.isSuccess())
        assertEquals(501, resp.httpStatus)
        assertEquals("501", resp.code)
    }
}
