package com.sniper.coconut.component

import android.content.Context
import io.mockk.mockk
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * Unit tests for [ComponentManager].
 *
 * Behavior note: unlike the iOS variant (which silently skips a registration
 * with unsatisfied dependencies), the Android `register()` THROWS
 * `ComponentException` for duplicate names or missing dependencies.
 */
class ComponentManagerTest {

    private val manager: ComponentManager get() = ComponentManager.getInstance()

    // Stable scope: sharedContext is lazy on the singleton, so it captures whichever
    // scope is set when the very first register() runs. A long-lived SupervisorJob
    // survives across tests; BaseComponent.init() does not actually dispatch onto it
    // in these tests.
    private val stableScope = CoroutineScope(SupervisorJob() + Dispatchers.Unconfined)

    @Before
    fun setUp() = runTest {
        // Inject a relaxed mock Context so the lazy sharedContext can initialize
        // without touching the Android runtime.
        manager.setApplicationContext(mockk<Context>(relaxed = true))
        manager.setCoroutineScope(stableScope)
        manager.cleanup()
    }

    @After
    fun tearDown() = runTest {
        manager.cleanup()
    }

    @Test
    fun register_andLookup_succeeds() = runTest {
        val plugin = MockPlugin(name = "device")
        manager.register(plugin)

        assertNotNull(manager.getComponent("device"))
        assertTrue(manager.getRegisteredComponents().contains("device"))
        assertTrue(manager.hasComponent("device"))
        assertEquals(1, plugin.initCallCount)
        assertTrue(plugin.isInitialized)
    }

    @Test
    fun register_duplicateThrowsAndKeepsFirst() = runTest {
        val first = MockPlugin(name = "dup")
        val second = MockPlugin(name = "dup")

        manager.register(first)
        assertThrows(ComponentException::class.java) {
            kotlinx.coroutines.runBlocking { manager.register(second) }
        }

        assertEquals(1, first.initCallCount)
        assertEquals(
            "Duplicate register must not init the second instance",
            0,
            second.initCallCount
        )
        assertTrue(manager.getRegisteredComponents().contains("dup"))
    }

    @Test
    fun getComponent_unknownReturnsNull() = runTest {
        assertNull(manager.getComponent("does-not-exist"))
        assertFalse(manager.hasComponent("does-not-exist"))
    }

    @Test
    fun register_withMissingDependency_throwsAndDoesNotRegister() = runTest {
        val pluginB = MockPlugin(name = "B", dependencies = listOf("A"))
        assertThrows(ComponentException::class.java) {
            kotlinx.coroutines.runBlocking { manager.register(pluginB) }
        }
        assertNull(manager.getComponent("B"))
        assertEquals(0, pluginB.initCallCount)
    }

    @Test
    fun register_withSatisfiedDependency_succeeds() = runTest {
        val pluginA = MockPlugin(name = "A")
        val pluginB = MockPlugin(name = "B", dependencies = listOf("A"))
        manager.register(pluginA)
        manager.register(pluginB)

        assertNotNull(manager.getComponent("A"))
        assertNotNull(manager.getComponent("B"))
    }

    @Test
    fun unregister_callsCleanupAndRemoves() = runTest {
        val plugin = MockPlugin(name = "removable")
        manager.register(plugin)
        manager.unregister("removable")

        assertNull(manager.getComponent("removable"))
        assertEquals(1, plugin.cleanupCallCount)
        assertFalse(plugin.isInitialized)
    }

    @Test
    fun unregister_unknown_isNoop() = runTest {
        // Should not throw or otherwise affect state.
        manager.unregister("never-existed")
    }

    @Test
    fun cleanup_callsCleanupOnAllAndClearsRegistry() = runTest {
        val p1 = MockPlugin(name = "c1")
        val p2 = MockPlugin(name = "c2")
        manager.register(p1)
        manager.register(p2)

        manager.cleanup()

        assertEquals(1, p1.cleanupCallCount)
        assertEquals(1, p2.cleanupCallCount)
        assertTrue(manager.getRegisteredComponents().isEmpty())
    }
}
