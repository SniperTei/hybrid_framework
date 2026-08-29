package com.sniper.androidwebbox.components.update

import com.sniper.coconut.component.ComponentException
import com.sniper.coconut.resource.OfflineResourceManager
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.JsonObject

import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/**
 * JVM tests for the update component state machine. All manager operations
 * are fake lambdas — no Context, no network.
 */
class UpdateComponentTest {

    companion object {
        private fun manifest(version: String = "9.9.9") = OfflineResourceManager.RemoteManifest(
            moduleId = "demo", version = version, entry = "index.html",
            files = listOf("index.html"), md5 = "x", fileHashes = mapOf("index.html" to "x"),
        )

        private fun checkResult(
            available: Boolean, current: String = "1.0.0", remote: String = "2.0.0",
            manifest: OfflineResourceManager.RemoteManifest? = null, error: String? = null,
        ) = OfflineResourceManager.UpdateCheckResult(available, current, remote, manifest, error)
    }


    private class Recorder {
        var lastManifest: OfflineResourceManager.RemoteManifest? = null
        var lastBaseUrl: String? = null
        var lastRollbackModule: String? = null
        var checkToReturn = checkResult(true, manifest = manifest())
        var performToReturn = OfflineResourceManager.UpdateResult(true, "demo", "2.0.0")
        var rollbackToReturn = true
        var localVersionToReturn = "1.0.0"
    }

    private fun component(rec: Recorder) = UpdateComponent(
        UpdateComponent.Deps(
            checkUpdate = { _, _ -> rec.checkToReturn },
            performUpdate = { m, b ->
                rec.lastManifest = m; rec.lastBaseUrl = b; rec.performToReturn
            },
            rollback = { m ->
                rec.lastRollbackModule = m; rec.rollbackToReturn
            },
            localVersion = { rec.localVersionToReturn },
        )
    )

    private fun params(vararg pairs: Pair<String, String>): JsonObject = buildJsonObject {
        pairs.forEach { (k, v) -> put(k, v) }
    }

    private fun JsonObject.bool(key: String) = jsonObject[key]!!.jsonPrimitive.boolean
    private fun JsonObject.str(key: String) = jsonObject[key]!!.jsonPrimitive.content

    @Test
    fun `check without manifestUrl throws 200007`() = runTest {
        try {
            component(Recorder()).handle("check", params())
            fail("should throw")
        } catch (e: ComponentException) {
            assertEquals("200007", e.code)
        }
    }

    @Test
    fun `check available exposes versions and caches manifest`() = runTest {
        val rec = Recorder()
        val c = component(rec)
        val r = c.handle("check", params("manifestUrl" to "http://host:8000/manifest.json"))
            .let { it as JsonObject }
        assertTrue(r.bool("available"))
        assertEquals("1.0.0", r.str("currentVersion"))
        assertEquals("2.0.0", r.str("remoteVersion"))

        // cached state drives a later parameterless apply
        c.handle("apply", params()).let { it as JsonObject }
        assertEquals("9.9.9", rec.lastManifest?.version)
        assertEquals("http://host:8000", rec.lastBaseUrl)
    }

    @Test
    fun `check transport error is business failure`() = runTest {
        val rec = Recorder()
        rec.checkToReturn = checkResult(false, error = "connection refused")
        val r = component(rec).handle("check", params("manifestUrl" to "http://x/m.json")) as JsonObject
        assertFalse(r.bool("success"))
        assertTrue(r.str("message").contains("connection refused"))
    }

    @Test
    fun `apply without check is business failure`() = runTest {
        val r = component(Recorder()).handle("apply", params()) as JsonObject
        assertFalse(r.bool("success"))
        assertTrue(r.str("message").contains("check first"))
    }

    @Test
    fun `apply after up-to-date check still fails`() = runTest {
        val rec = Recorder()
        rec.checkToReturn = checkResult(false, manifest = manifest())
        val c = component(rec)
        c.handle("check", params("manifestUrl" to "http://x/m.json"))
        val r = c.handle("apply", params()) as JsonObject
        assertFalse(r.bool("success"))
    }

    @Test
    fun `apply failure surfaces manager error`() = runTest {
        val rec = Recorder()
        rec.performToReturn = OfflineResourceManager.UpdateResult(false, "demo", "", error = "md5 mismatch")
        val c = component(rec)
        c.handle("check", params("manifestUrl" to "http://x/m.json"))
        val r = c.handle("apply", params()) as JsonObject
        assertFalse(r.bool("success"))
        assertTrue(r.str("message").contains("md5 mismatch"))
    }

    @Test
    fun `rollback ok returns restored version`() = runTest {
        val rec = Recorder()
        rec.localVersionToReturn = "1.0.0"
        val r = component(rec).handle("rollback", params()) as JsonObject
        assertTrue(r.bool("success"))
        assertEquals("1.0.0", r.str("version"))
        assertEquals("demo", rec.lastRollbackModule)
    }

    @Test
    fun `rollback with nothing staged is business failure`() = runTest {
        val rec = Recorder()
        rec.rollbackToReturn = false
        val r = component(rec).handle("rollback", params()) as JsonObject
        assertFalse(r.bool("success"))
    }

    @Test
    fun `version returns local module version`() = runTest {
        val rec = Recorder()
        rec.localVersionToReturn = "3.2.1"
        val r = component(rec).handle("version", params()) as JsonObject
        assertEquals("3.2.1", r.str("version"))
    }

    @Test
    fun `unknown function throws`() = runTest {
        try {
            component(Recorder()).handle("reboot", params())
            fail("should throw")
        } catch (e: ComponentException) {
            assertTrue(e.message!!.contains("reboot"))
        }
    }
}
