package com.sniper.coconut.resource

import android.content.Context
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.ByteArrayInputStream
import java.io.File
import java.io.FileNotFoundException

/**
 * JVM unit tests for [OfflineResourceManager].
 *
 * Network paths are not covered here (no HTTP server); the update decision /
 * validation / hash / swap logic lives in pure companion functions and is
 * tested directly. The Context mock stubs `filesDir` to a temp directory and
 * makes `assets` behave as "no bundled package" unless a test overrides it.
 */
class OfflineResourceManagerTest {

    @get:Rule
    val tmp = TemporaryFolder()

    private val context: Context = mockk(relaxed = true)
    private lateinit var sandboxRoot: File
    private lateinit var manager: OfflineResourceManager

    @Before
    fun setUp() {
        sandboxRoot = tmp.newFolder("files").resolve("coconut_resources")
        every { context.filesDir } returns sandboxRoot.parentFile
        // Default: no bundled package (AssetManager unavailable on JVM).
        every { context.assets.open(any<String>()) } throws FileNotFoundException("no assets in JVM test")
        every { context.assets.list(any<String>()) } returns emptyArray()

        manager = OfflineResourceManager(context)
        manager.init()
    }

    private fun stubBundledManifest(moduleId: String, version: String) {
        val manifestJson = """{"moduleId":"$moduleId","version":"$version","files":["index.html"],"md5":"x"}"""
        every { context.assets.list("coconut-web") } returns arrayOf(moduleId)
        // answers {} so every call gets a fresh stream (a shared instance drains on first read)
        every { context.assets.open("coconut-web/$moduleId/manifest.json") } answers {
            ByteArrayInputStream(manifestJson.toByteArray())
        }
    }

    // ---- compareVersions ----

    @Test
    fun compareVersions_equalVersions() {
        assertEquals(0, OfflineResourceManager.compareVersions("1.0.0", "1.0.0"))
    }

    @Test
    fun compareVersions_higherPatchWins() {
        assertTrue(OfflineResourceManager.compareVersions("1.0.1", "1.0.0") > 0)
        assertTrue(OfflineResourceManager.compareVersions("0.9.9", "1.0.0") < 0)
    }

    @Test
    fun compareVersions_majorBeatsMinor() {
        assertTrue(OfflineResourceManager.compareVersions("2.0.0", "1.99.99") > 0)
    }

    @Test
    fun compareVersions_missingSegmentsAreZero() {
        assertEquals(0, OfflineResourceManager.compareVersions("1.2", "1.2.0"))
    }

    @Test
    fun compareVersions_nonNumericSegmentsParseAsZero() {
        assertEquals(0, OfflineResourceManager.compareVersions("x.y.z", "0.0.0"))
    }

    // ---- isSafePackagePath ----

    @Test
    fun isSafePackagePath_acceptsPlainAndNestedPaths() {
        assertTrue(OfflineResourceManager.isSafePackagePath("index.html"))
        assertTrue(OfflineResourceManager.isSafePackagePath("js/app.js"))
        assertTrue(OfflineResourceManager.isSafePackagePath("assets/fonts/v1/font.woff2"))
    }

    @Test
    fun isSafePackagePath_rejectsTraversalAndAbsolute() {
        assertFalse(OfflineResourceManager.isSafePackagePath(""))
        assertFalse(OfflineResourceManager.isSafePackagePath("/etc/passwd"))
        assertFalse(OfflineResourceManager.isSafePackagePath("../escape.js"))
        assertFalse(OfflineResourceManager.isSafePackagePath("a/../../escape.js"))
        assertFalse(OfflineResourceManager.isSafePackagePath("a\\b.js"))
        assertFalse(OfflineResourceManager.isSafePackagePath("a//b.js"))
        assertFalse(OfflineResourceManager.isSafePackagePath("."))
    }

    // ---- md5Hex ----

    @Test
    fun md5Hex_knownVectors() {
        assertEquals("5d41402abc4b2a76b9719d911017c592", OfflineResourceManager.md5Hex("hello".toByteArray()))
        assertEquals("d41d8cd98f00b204e9800998ecf8427e", OfflineResourceManager.md5Hex(ByteArray(0)))
    }

    // ---- decideUpdate ----

    @Test
    fun decideUpdate_remoteAboveBoth_isAvailable() {
        assertTrue(OfflineResourceManager.decideUpdate("1.0.0", "1.0.0", "1.0.1"))
    }

    @Test
    fun decideUpdate_remoteEqualsBundled_notAvailable() {
        assertFalse(OfflineResourceManager.decideUpdate(null, "1.0.1", "1.0.1"))
    }

    @Test
    fun decideUpdate_sandboxAheadOfRemote_notAvailable() {
        assertFalse(OfflineResourceManager.decideUpdate("1.2.0", "1.0.0", "1.1.0"))
    }

    @Test
    fun decideUpdate_noLocalVersions_remoteAboveZero() {
        assertTrue(OfflineResourceManager.decideUpdate(null, null, "0.0.1"))
    }

    // ---- validateManifest ----

    @Test
    fun validateManifest_validManifestPasses() {
        val manifest = OfflineResourceManager.RemoteManifest(
            moduleId = "demo",
            version = "1.0.1",
            files = listOf("index.html", "js/app.js"),
            fileHashes = mapOf("index.html" to "aa", "js/app.js" to "bb")
        )
        assertNull(OfflineResourceManager.validateManifest(manifest))
    }

    @Test
    fun validateManifest_emptyFileListRejected() {
        val manifest = OfflineResourceManager.RemoteManifest(moduleId = "demo", version = "1.0.1")
        assertEquals("manifest has no files", OfflineResourceManager.validateManifest(manifest))
    }

    @Test
    fun validateManifest_missingHashEntryRejected_failClosed() {
        val manifest = OfflineResourceManager.RemoteManifest(
            moduleId = "demo",
            version = "1.0.1",
            files = listOf("index.html"),
            fileHashes = emptyMap()
        )
        assertEquals(
            "missing fileHashes entry: index.html",
            OfflineResourceManager.validateManifest(manifest)
        )
    }

    @Test
    fun validateManifest_unsafePathRejected() {
        val manifest = OfflineResourceManager.RemoteManifest(
            moduleId = "demo",
            version = "1.0.1",
            files = listOf("../evil.js"),
            fileHashes = mapOf("../evil.js" to "aa")
        )
        assertEquals(
            "unsafe package path: ../evil.js",
            OfflineResourceManager.validateManifest(manifest)
        )
    }

    // ---- verifyDownloaded ----

    @Test
    fun verifyDownloaded_allHashesMatch_returnsNull() {
        val staging = tmp.newFolder("staging-ok")
        File(staging, "index.html").writeText("hello")
        val manifest = OfflineResourceManager.RemoteManifest(
            moduleId = "demo",
            version = "1.0.1",
            files = listOf("index.html"),
            fileHashes = mapOf("index.html" to OfflineResourceManager.md5Hex("hello".toByteArray()).uppercase())
        )
        assertNull(OfflineResourceManager.verifyDownloaded(staging, manifest))
    }

    @Test
    fun verifyDownloaded_tamperedFile_reportsFile_andOldModuleUntouched() {
        val sandbox = tmp.newFolder("sandbox1").resolve("coconut_resources")
        val oldModule = sandbox.resolve("demo").apply {
            mkdirs()
            resolve("index.html").writeText("OLD VERSION")
        }
        val staging = sandbox.resolve(".staging_demo").apply {
            mkdirs()
            resolve("index.html").writeText("TAMPERED")
        }
        val manifest = OfflineResourceManager.RemoteManifest(
            moduleId = "demo",
            version = "1.0.1",
            files = listOf("index.html"),
            fileHashes = mapOf("index.html" to OfflineResourceManager.md5Hex("hello".toByteArray()))
        )
        assertEquals("index.html", OfflineResourceManager.verifyDownloaded(staging, manifest))
        // Old version untouched by verification failure
        assertEquals("OLD VERSION", oldModule.resolve("index.html").readText())
    }

    // ---- swapStaged ----

    @Test
    fun swapStaged_replacesModuleDirAtomically() {
        val sandbox = tmp.newFolder("sandbox2").resolve("coconut_resources").apply { mkdirs() }
        sandbox.resolve("demo").apply {
            mkdirs()
            resolve("index.html").writeText("OLD")
        }
        val staging = sandbox.resolve(".staging_demo").apply {
            mkdirs()
            resolve("index.html").writeText("NEW")
            resolve("js").mkdirs()
            resolve("js/app.js").writeText("console.log(1)")
        }

        OfflineResourceManager.swapStaged(sandbox, "demo")

        assertEquals("NEW", sandbox.resolve("demo/index.html").readText())
        assertEquals("console.log(1)", sandbox.resolve("demo/js/app.js").readText())
        assertFalse(staging.exists())
    }

    // ---- rollback (with mocked filesDir + bundled manifest) ----

    @Test
    fun rollback_clearsSandboxDirAndVersionEntry_remergesBundled() = runTest {
        stubBundledManifest("demo", "1.0.0")
        // Simulate an installed hot update
        sandboxRoot.resolve("demo").apply {
            mkdirs()
            resolve("index.html").writeText("HOT UPDATE v1.0.1")
        }
        sandboxRoot.resolve("version.json").writeText("""{"demo":"1.0.1"}""")
        manager.init() // reload sandbox + bundled versions
        assertEquals("1.0.1", manager.getLocalVersion("demo"))

        assertTrue(manager.rollback("demo"))

        assertFalse(sandboxRoot.resolve("demo").exists())
        val persisted = sandboxRoot.resolve("version.json").readText()
        assertFalse("version entry must be removed", persisted.contains("\"demo\""))
        // Bundled version re-merged into memory
        assertEquals("1.0.0", manager.getLocalVersion("demo"))
    }

    // ---- checkUpdate failure path (connection refused, no server) ----

    @Test
    fun checkUpdate_unreachableManifest_reportsError() = runTest {
        stubBundledManifest("demo", "1.0.0")
        manager.init()

        val result = manager.checkUpdate("demo", "http://127.0.0.1:1/manifest.json")

        assertFalse(result.available)
        assertNotNull(result.error)
        assertEquals("1.0.0", result.currentVersion)
    }
}
