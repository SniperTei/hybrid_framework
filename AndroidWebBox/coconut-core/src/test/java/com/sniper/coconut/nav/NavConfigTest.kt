package com.sniper.coconut.nav

import com.sniper.coconut.nav.NavConfig.ClosePolicy
import com.sniper.coconut.nav.NavConfig.TitleMode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class NavConfigTest {

    // ---- defaults ----

    @Test
    fun `default is visible with AUTO title and AUTO close policy`() {
        val d = NavConfig.default()
        assertEquals(true, d.visible)
        assertEquals(TitleMode.AUTO, d.titleMode)
        assertEquals(ClosePolicy.AUTO, d.closePolicy)
        assertNull(d.titleText)
        assertNull(d.leftButtonText)
        assertNull(d.rightButtonText)
    }

    // ---- merge: null = inherit, non-null = override, per field ----

    @Test
    fun `merge keeps base fields when override is all null`() {
        val base = NavConfig.default().apply {
            titleMode = TitleMode.FIXED
            titleText = "基座"
            leftButtonText = "取消"
        }
        val merged = NavConfig.merge(base, NavConfig())
        assertEquals(true, merged.visible)
        assertEquals(TitleMode.FIXED, merged.titleMode)
        assertEquals("基座", merged.titleText)
        assertEquals("取消", merged.leftButtonText)
    }

    @Test
    fun `merge overrides only the fields set`() {
        val base = NavConfig.default().apply {
            titleText = "旧标题"
            rightButtonText = "旧按钮"
        }
        val merged = NavConfig.merge(base, NavConfig(visible = false))
        assertEquals(false, merged.visible)
        assertEquals("旧标题", merged.titleText)
        assertEquals("旧按钮", merged.rightButtonText)
    }

    @Test
    fun `merge does not alias input instances`() {
        val base = NavConfig.default()
        val override = NavConfig(visible = false)
        val merged = NavConfig.merge(base, override)
        override.visible = true
        assertEquals(false, merged.visible)
    }

    @Test
    fun `merge chain global then template then header resolves per field`() {
        val global = NavConfig.default().apply { rightButtonText = "全局分享" }
        val template = NavConfig(titleMode = TitleMode.FIXED, titleText = "模板页")
        val header = NavConfig(visible = false, titleText = "H5 标题")
        val merged = NavConfig.merge(NavConfig.merge(global, template), header)
        assertEquals(false, merged.visible)                 // header wins
        assertEquals(TitleMode.FIXED, merged.titleMode)     // template wins
        assertEquals("H5 标题", merged.titleText)            // header wins
        assertEquals("全局分享", merged.rightButtonText)      // global wins
    }

    // ---- shouldShowClose truth table ----

    @Test
    fun `closePolicy AUTO shows close only at stack root`() {
        val cfg = NavConfig(closePolicy = ClosePolicy.AUTO)
        assertTrue(cfg.shouldShowClose(canGoBack = false))
        assertFalse(cfg.shouldShowClose(canGoBack = true))
    }

    @Test
    fun `closePolicy ALWAYS shows close regardless of history`() {
        val cfg = NavConfig(closePolicy = ClosePolicy.ALWAYS)
        assertTrue(cfg.shouldShowClose(canGoBack = false))
        assertTrue(cfg.shouldShowClose(canGoBack = true))
    }

    @Test
    fun `unresolved closePolicy falls back to AUTO semantics`() {
        val cfg = NavConfig()
        assertTrue(cfg.shouldShowClose(canGoBack = false))
        assertFalse(cfg.shouldShowClose(canGoBack = true))
    }

    // ---- parseOverride ----

    @Test
    fun `parseOverride reads all fields`() {
        val cfg = NavConfig.parseOverride(
            """{"visible":false,"title":"订单详情","closePolicy":"always",
               "leftButtonText":"取消","rightButtonText":"分享"}"""
        )!!
        assertEquals(false, cfg.visible)
        assertEquals(TitleMode.FIXED, cfg.titleMode)
        assertEquals("订单详情", cfg.titleText)
        assertEquals(ClosePolicy.ALWAYS, cfg.closePolicy)
        assertEquals("取消", cfg.leftButtonText)
        assertEquals("分享", cfg.rightButtonText)
    }

    @Test
    fun `parseOverride title auto maps to AUTO mode`() {
        val cfg = NavConfig.parseOverride("""{"title":"auto"}""")!!
        assertEquals(TitleMode.AUTO, cfg.titleMode)
        assertNull(cfg.titleText)
    }

    @Test
    fun `parseOverride closePolicy auto inherits (null)`() {
        val cfg = NavConfig.parseOverride("""{"closePolicy":"auto"}""")!!
        assertNull(cfg.closePolicy)
    }

    @Test
    fun `parseOverride empty object yields all-null override`() {
        val cfg = NavConfig.parseOverride("{}")!!
        assertNull(cfg.visible)
        assertNull(cfg.titleMode)
    }

    @Test
    fun `parseOverride malformed json returns null`() {
        assertNull(NavConfig.parseOverride("{not json"))
        assertNull(NavConfig.parseOverride(""))
    }

    // ---- legacy extras mapping ----

    @Test
    fun `legacy extras map onto override slots`() {
        // Simulates CoconutWebActivity mapping: visible=false + titleText="旧调用方"
        val legacy = NavConfig(visible = false, titleMode = TitleMode.FIXED, titleText = "旧调用方")
        val merged = NavConfig.merge(NavConfig.default(), legacy)
        assertEquals(false, merged.visible)
        assertEquals(TitleMode.FIXED, merged.titleMode)
        assertEquals("旧调用方", merged.titleText)
    }

    @Test
    fun `legacy titleText absent keeps AUTO default`() {
        // Old caller passing only titleBarVisible=true → new AUTO sync behavior
        val legacy = NavConfig(visible = true)
        val merged = NavConfig.merge(NavConfig.default(), legacy)
        assertEquals(TitleMode.AUTO, merged.titleMode)
    }
}
