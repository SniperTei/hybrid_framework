package com.sniper.androidwebbox.components.navigator

import android.app.Activity
import android.content.Context
import com.sniper.coconut.component.ComponentException
import com.sniper.coconut.component.ComponentHost
import com.sniper.coconut.component.ComponentManager
import com.sniper.coconut.web.CoconutWebActivity
import io.mockk.mockk
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.put
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test

class NavigatorComponentTest {

    private data class Launch(
        val url: String,
        val navJson: String?,
        val targetClass: Class<*>,
    )

    private val launches = mutableListOf<Launch>()
    private var depth = 1
    private val templates = mutableMapOf<String, Class<*>>()

    private lateinit var component: NavigatorComponent
    private val mockActivity: Activity = mockk(relaxed = true)

    companion object {
        // ComponentManager.sharedContext 是 lazy 单例，所有测试类必须共用同一 mock
        private val mockContext: Context = com.sniper.androidwebbox.components.TestSharedContext.mockContext
    }

    @Before
    fun setUp() {
        launches.clear()
        depth = 1
        templates.clear()
        component = NavigatorComponent(
            stackDepthSupplier = { depth },
            launcher = { url, navJson, targetClass, _ ->
                launches.add(Launch(url, navJson, targetClass))
            },
            templateResolver = { templates },
        )

        ComponentManager.getInstance().apply {
            setApplicationContext(mockContext)
            setCoroutineScope(CoroutineScope(SupervisorJob()))
            setHost(mockk<ComponentHost>(relaxed = true).also {
                io.mockk.every { it.getActivity() } returns mockActivity
            })
        }
    }

    @After
    fun tearDown() = kotlinx.coroutines.runBlocking {
        try {
            ComponentManager.getInstance().unregister("navigator")
        } catch (e: Exception) {
            // 未注册时静默
        }
        ComponentManager.getInstance().setHost(null)
    }

    private suspend fun register(): NavigatorComponent {
        ComponentManager.getInstance().register(component)
        return component
    }

    private fun params(vararg pairs: Pair<String, kotlinx.serialization.json.JsonElement>) =
        buildJsonObject {
            for ((k, v) in pairs) put(k, v)
        }

    private fun s(value: String) = Json.parseToJsonElement("\"$value\"")

    // ---- forward ----

    @Test
    fun forward_happyPath_standardContainer() = runTest {
        register()
        val result = component.handle("forward", params("url" to s("https://example.com/page")))
        assertTrue(result.jsonObject["success"]!!.jsonPrimitive.boolean)
        assertEquals(1, launches.size)
        assertEquals("https://example.com/page", launches[0].url)
        assertEquals(CoconutWebActivity::class.java, launches[0].targetClass)
        assertNull(launches[0].navJson)
    }

    @Test
    fun forward_missingUrl_200007() = runTest {
        register()
        try {
            component.handle("forward", params())
            fail("expected ComponentException")
        } catch (e: ComponentException) {
            assertEquals("200007", e.code)
        }
        assertEquals(0, launches.size)
    }

    @Test
    fun forward_coconutScheme_bypassesDomainGuard() = runTest {
        register()
        val result = component.handle("forward", params("url" to s("coconut://demo/index.html")))
        assertTrue(result.jsonObject["success"]!!.jsonPrimitive.boolean)
        assertEquals("coconut://demo/index.html", launches[0].url)
    }

    @Test
    fun forward_badScheme_200007() = runTest {
        register()
        try {
            component.handle("forward", params("url" to s("javascript:alert(1)")))
            fail("expected ComponentException")
        } catch (e: ComponentException) {
            assertEquals("200007", e.code)
        }
        assertEquals(0, launches.size)
    }

    @Test
    fun forward_relativeUrl_rejected_200007() = runTest {
        // coconut.js resolves relative → absolute before sending; a bare
        // relative url reaching native means a broken caller → fail loud
        register()
        try {
            component.handle("forward", params("url" to s("/order/detail")))
            fail("expected ComponentException")
        } catch (e: ComponentException) {
            assertEquals("200007", e.code)
        }
    }

    @Test
    fun forward_stackLimit_businessFailure() = runTest {
        register()
        depth = NavigatorComponent.MAX_STACK_DEPTH
        val result = component.handle("forward", params("url" to s("https://example.com/")))
        assertFalse(result.jsonObject["success"]!!.jsonPrimitive.boolean)
        assertTrue(result.jsonObject["message"]!!.jsonPrimitive.content.contains("stack limit"))
        assertEquals(0, launches.size)
    }

    @Test
    fun forward_templateHit_launchesTemplateClass() = runTest {
        register()
        templates["demo"] = String::class.java  // 任意 Class 占位
        val result = component.handle(
            "forward",
            params(
                "url" to s("https://example.com/tpl"),
                "template" to s("demo"),
            ),
        )
        assertTrue(result.jsonObject["success"]!!.jsonPrimitive.boolean)
        assertEquals(String::class.java, launches[0].targetClass)
    }

    @Test
    fun forward_templateNotRegistered_businessFailure() = runTest {
        register()
        val result = component.handle(
            "forward",
            params("url" to s("https://example.com/tpl"), "template" to s("typo")),
        )
        assertFalse(result.jsonObject["success"]!!.jsonPrimitive.boolean)
        assertTrue(result.jsonObject["message"]!!.jsonPrimitive.content.contains("template not registered"))
        assertEquals(0, launches.size)
    }

    @Test
    fun forward_paramsFlattenToQuery_andHeaderToNavJson() = runTest {
        register()
        val result = component.handle(
            "forward",
            params(
                "url" to s("https://example.com/page?x=1"),
                "params" to buildJsonObject {
                    put("id", 123)
                    put("from", "list")
                },
                "header" to buildJsonObject {
                    put("title", "订单详情")
                    put("rightButtonText", "分享")
                },
            ),
        )
        assertTrue(result.jsonObject["success"]!!.jsonPrimitive.boolean)
        val launch = launches[0]
        assertEquals("https://example.com/page?x=1&id=123&from=list", launch.url)
        assertNotNull(launch.navJson)
        assertTrue(launch.navJson!!.contains("订单详情"))
        assertTrue(launch.navJson!!.contains("分享"))
    }

    @Test
    fun forward_urlEncodedParams() = runTest {
        register()
        component.handle(
            "forward",
            params(
                "url" to s("https://example.com/search"),
                "params" to buildJsonObject { put("q", "a b&c") },
            ),
        )
        assertEquals("https://example.com/search?q=a+b%26c", launches[0].url)
    }

    // ---- close ----

    @Test
    fun close_withoutResult_ack() = runTest {
        register()
        val result = component.handle("close", null)
        assertTrue(result.jsonObject["success"]!!.jsonPrimitive.boolean)
        assertNull(com.sniper.coconut.web.NavResultBus.consume())
    }

    @Test
    fun close_withResult_postsToBus() = runTest {
        register()
        val result = component.handle(
            "close",
            params("result" to buildJsonObject { put("id", 123) }),
        )
        assertTrue(result.jsonObject["success"]!!.jsonPrimitive.boolean)
        val posted = com.sniper.coconut.web.NavResultBus.consume()
        assertNotNull(posted)
        assertTrue(posted!!.contains("\"id\":123"))
        assertNull(com.sniper.coconut.web.NavResultBus.consume())  // 单槽：消费后清空
    }

    // ---- misc ----

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

    @Test
    fun appendQuery_mergesWithExistingQuery() {
        val component = NavigatorComponent({ 0 }, { _, _, _, _ -> }, { emptyMap() })
        assertEquals(
            "https://a.com/p?x=1&k=v",
            component.appendQuery("https://a.com/p?x=1", buildJsonObject { put("k", "v") }),
        )
        assertEquals(
            "https://a.com/p?k=v",
            component.appendQuery("https://a.com/p", buildJsonObject { put("k", "v") }),
        )
        assertEquals("https://a.com/p", component.appendQuery("https://a.com/p", null))
    }
}
