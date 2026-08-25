package com.sniper.coconut.nav

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class TemplateRegistryTest {

    // Test fixtures: base class + subclass resolvable via Class.forName
    open class BaseContainer
    class DemoContainer : BaseContainer()
    class OtherContainer

    private val loader = TemplateRegistryTest::class.java.classLoader

    private val demoFqcn = DemoContainer::class.java.name
    private val otherFqcn = OtherContainer::class.java.name

    // ---- parse ----

    @Test
    fun `parse reads entries and ignores unknown keys`() {
        val entries = TemplateRegistry.parse(
            """[{"templateName":"demo","templatePage":"$demoFqcn","extra":1}]"""
        )
        assertEquals(1, entries.size)
        assertEquals("demo", entries[0].templateName)
    }

    @Test(expected = Exception::class)
    fun `parse malformed json throws`() {
        TemplateRegistry.parse("{not json")
    }

    // ---- validate ----

    private fun demoEntry() = TemplateEntry("demo", demoFqcn)

    @Test
    fun `validate resolves subclass into class map`() {
        val map = TemplateRegistry.validate(listOf(demoEntry()), loader, BaseContainer::class.java)
        assertEquals(DemoContainer::class.java, map["demo"])
    }

    @Test
    fun `validate rejects class not found`() {
        try {
            TemplateRegistry.validate(
                listOf(TemplateEntry("demo", "com.sniper.NoSuchClass")),
                loader,
                BaseContainer::class.java,
            )
            fail("expected IllegalStateException")
        } catch (e: IllegalStateException) {
            assertTrue(e.message!!.contains("class not found"))
            assertTrue(e.message!!.contains("demo"))
        }
    }

    @Test
    fun `validate rejects non-subclass`() {
        try {
            TemplateRegistry.validate(
                listOf(TemplateEntry("bad", otherFqcn)),
                loader,
                BaseContainer::class.java,
            )
            fail("expected IllegalStateException")
        } catch (e: IllegalStateException) {
            assertTrue(e.message!!.contains("not a subclass"))
        }
    }

    @Test
    fun `validate rejects duplicate names`() {
        try {
            TemplateRegistry.validate(
                listOf(demoEntry(), demoEntry()),
                loader,
                BaseContainer::class.java,
            )
            fail("expected IllegalStateException")
        } catch (e: IllegalStateException) {
            assertTrue(e.message!!.contains("duplicate templateName"))
        }
    }

    @Test
    fun `validate rejects blank name`() {
        try {
            TemplateRegistry.validate(
                listOf(TemplateEntry(" ", demoFqcn)),
                loader,
                BaseContainer::class.java,
            )
            fail("expected IllegalStateException")
        } catch (e: IllegalStateException) {
            assertTrue(e.message!!.contains("blank templateName"))
        }
    }
}
