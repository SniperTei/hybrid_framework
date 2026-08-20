package com.sniper.coconut.network

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class HttpRequestTest {

    @Test
    fun defaultMethod_isGet() {
        val req = HttpRequest("/x")
        assertEquals(HttpMethod.GET, req.method)
        assertEquals(-1, req.connectTimeout)
        assertEquals(-1, req.readTimeout)
    }

    @Test
    fun postParams_becomeBody() {
        val req = HttpRequest("/x", RequestOptions(method = HttpMethod.POST, params = mapOf("a" to "1")))
        assertEquals("1", req.body!!.jsonObject["a"]!!.jsonPrimitive.content)
        assertTrue(req.params.isEmpty())
    }

    @Test
    fun putParams_becomeBody() {
        val req = HttpRequest("/x", RequestOptions(method = HttpMethod.PUT, params = mapOf("a" to "1")))
        assertEquals("1", req.body!!.jsonObject["a"]!!.jsonPrimitive.content)
    }

    @Test
    fun getParams_stayAsQuery() {
        val req = HttpRequest("/x", RequestOptions(method = HttpMethod.GET, params = mapOf("a" to "1")))
        assertEquals("1", req.params["a"])
        assertNull(req.body)
    }

    @Test
    fun explicitBody_overridesParamsBody() {
        val body = Json.parseToJsonElement("""{"b": "2"}""")
        val req = HttpRequest(
            "/x",
            RequestOptions(method = HttpMethod.POST, params = mapOf("a" to "1"), body = body),
        )
        assertEquals(body, req.body)
    }

    @Test
    fun chainSetters_returnSelf() {
        val req = HttpRequest("/x")
        val body = Json.parseToJsonElement("""{"k": "v"}""")
        val self = req.setHeader("X-A", "1").setBody(body).setTag("t1").setTimeout(100, 200)
        assertSame(req, self)
        assertEquals("1", req.headers["X-A"])
        assertEquals(body, req.body)
        assertEquals("t1", req.tag)
        assertEquals(100, req.connectTimeout)
        assertEquals(200, req.readTimeout)
    }

    @Test
    fun buildCall_withoutContext_throws() {
        val req = HttpRequest("/x")
        try {
            req.buildCall()
            fail("expected IllegalStateException")
        } catch (e: IllegalStateException) {
            assertTrue(e.message!!.contains("未绑定 HttpClient"))
        }
    }

    @Test
    fun buildCall_withClientContext_returnsCall() {
        val client = HttpClient(HttpConfig())
        val req = client.newRequest("/x")
        val call = req.buildCall()
        // Call 构造成功即可（internal constructor，类型由执行路径验证）
        assertTrue(call is Call)
    }
}
