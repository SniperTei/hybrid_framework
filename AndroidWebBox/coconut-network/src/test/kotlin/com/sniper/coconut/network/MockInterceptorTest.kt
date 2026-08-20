package com.sniper.coconut.network

import com.sniper.coconut.network.interceptors.MockInterceptor
import com.sniper.coconut.network.interceptors.MockRule
import com.sniper.coconut.network.utils.Logger
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class MockInterceptorTest {

    private lateinit var fake: FakeAdapter
    private lateinit var client: HttpClient
    private lateinit var mock: MockInterceptor

    @Before
    fun setUp() {
        Logger.sink = { _, _, _ -> }
        fake = FakeAdapter()
        fake.envelopeResponse(200, """{"code":"000000","msg":"real"}""")
        mock = MockInterceptor()
        val config = HttpConfig()
        config.baseUrl = "https://api.test.com" // passthrough 用例需完整 URL 过 UrlGuard
        config.retryDelay = 10
        client = HttpClient(config, fake)
        client.addInterceptor(mock)
    }

    @Test
    fun exactUrlHit_returnsMockData_skipsAdapter() = runTest {
        mock.addRule(
            MockRule(url = "/api/user", method = HttpMethod.GET, data = Json.parseToJsonElement("""{"name":"test"}"""))
        )
        val resp = client.newRequest("/api/user").buildCall().execute()
        assertTrue(resp.isSuccess())
        assertEquals(200, resp.httpStatus)
        assertEquals("test", resp.data!!.jsonObject["name"]!!.jsonPrimitive.content)
        assertEquals(0, fake.sendCount)
    }

    @Test
    fun prefixUrlHit_withWildcard() = runTest {
        mock.addRule(MockRule(url = "/api/items*", data = Json.parseToJsonElement("""{"list":[]}""")))
        val resp = client.newRequest("/api/items/1").buildCall().execute()
        assertTrue(resp.isSuccess())
        assertEquals(0, fake.sendCount)
    }

    @Test
    fun methodMismatch_passesThroughToAdapter() = runTest {
        mock.addRule(MockRule(url = "/api/user", method = HttpMethod.POST, data = Json.parseToJsonElement("{}")))
        val resp = client.newRequest("/api/user").buildCall().execute() // GET
        assertEquals(1, fake.sendCount)
        assertEquals("real", resp.msg)
    }

    @Test
    fun urlMismatch_passesThroughToAdapter() = runTest {
        mock.addRule(MockRule(url = "/api/other", data = Json.parseToJsonElement("{}")))
        client.newRequest("/api/user").buildCall().execute()
        assertEquals(1, fake.sendCount)
    }

    @Test
    fun errorRule_mockFailures_withStatusAndCode() = runTest {
        mock.addRule(MockRule(url = "/api/login", httpStatus = 500, code = "500000", msg = "mock fail"))
        val resp = client.newRequest("/api/login", RequestOptions(method = HttpMethod.POST)).buildCall().execute()
        assertFalse(resp.isSuccess())
        assertEquals(500, resp.httpStatus)
        assertEquals("500000", resp.code)
        assertEquals("mock fail", resp.msg)
        assertEquals(0, fake.sendCount)
    }

    @Test
    fun mockRule_anyMethod_whenOmitted() = runTest {
        mock.addRule(MockRule(url = "/api/any", data = Json.parseToJsonElement("""{"ok":1}""")))
        val respGet = client.newRequest("/api/any").buildCall().execute()
        val respPost = client.newRequest("/api/any", RequestOptions(method = HttpMethod.POST)).buildCall().execute()
        assertTrue(respGet.isSuccess())
        assertTrue(respPost.isSuccess())
        assertEquals(0, fake.sendCount)
    }

    @Test
    fun clearAll_removesRules() = runTest {
        mock.addRule(MockRule(url = "/api/user", data = Json.parseToJsonElement("{}")))
        mock.clearAll()
        client.newRequest("/api/user").buildCall().execute()
        assertEquals(1, fake.sendCount)
    }

    @Test
    fun manualEnableMocking_withoutInterceptor() = runTest {
        val bareClient = HttpClient(HttpConfig(), fake)
        val resp = bareClient.newRequest("/api/user")
            .enableMocking(Json.parseToJsonElement("""{"name":"manual"}"""))
            .buildCall().execute()
        assertTrue(resp.isSuccess())
        assertEquals("manual", resp.data!!.jsonObject["name"]!!.jsonPrimitive.content)
        assertEquals(0, fake.sendCount)
    }

    @Test
    fun mockSkipsUrlGuard_notBlocked() = runTest {
        // 守卫配置成拦所有，mock 仍应短路成功（mock 不出网）
        val config = HttpConfig()
        config.allowedDomains = listOf("foo.com")
        val guardedClient = HttpClient(config, fake)
        guardedClient.addInterceptor(mock)
        mock.addRule(MockRule(url = "http://evil.com/api", data = Json.parseToJsonElement("""{"ok":1}""")))
        val resp = guardedClient.newRequest("http://evil.com/api").buildCall().execute()
        assertTrue(resp.isSuccess())
        assertEquals(0, fake.sendCount)
    }
}
