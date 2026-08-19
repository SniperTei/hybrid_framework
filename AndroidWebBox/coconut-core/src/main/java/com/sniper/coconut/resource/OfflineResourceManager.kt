package com.sniper.coconut.resource

import android.content.Context
import com.sniper.coconut.utils.Logger
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap

/**
 * Offline Resource Manager
 *
 * Manages H5 resources:
 * - Loads from assets (bundled with APK) as baseline
 * - Serves sandbox overlay over bundled assets (coconut:// scheme)
 * - Hot update: per-file download with md5 verification, staged atomically
 * - Version management: sandbox version.json vs bundled manifest version
 */
class OfflineResourceManager(private val context: Context) {

    private val json = Json { ignoreUnknownKeys = true }

    // Resource root in sandbox
    private val resourceDir = File(context.filesDir, "coconut_resources")

    // Module versions: moduleId -> version string
    private val localVersions = ConcurrentHashMap<String, String>()

    // ---- Data Models ----

    @Serializable
    data class ModuleVersion(
        val moduleId: String = "",
        val version: String = "0.0.0",
        val files: List<String> = emptyList(),
        val md5: String = ""
    )

    /**
     * Manifest served by the update server. Superset of [ModuleVersion]:
     * `fileHashes` maps each entry of `files` to its md5 (lowercase hex).
     */
    @Serializable
    data class RemoteManifest(
        val moduleId: String = "",
        val version: String = "",
        val entry: String = "",
        val files: List<String> = emptyList(),
        val md5: String = "",
        val fileHashes: Map<String, String> = emptyMap()
    )

    data class UpdateCheckResult(
        val available: Boolean,
        val currentVersion: String,
        val remoteVersion: String,
        val manifest: RemoteManifest? = null,
        val error: String? = null
    )

    data class UpdateResult(
        val success: Boolean,
        val moduleId: String,
        val version: String,
        val error: String? = null
    )

    // ---- Init ----

    /**
     * Initialize: read local versions from sandbox
     */
    fun init() {
        if (!resourceDir.exists()) {
            resourceDir.mkdirs()
        }
        loadLocalVersions()
        Logger.i(TAG, "ResourceManager initialized, modules: ${localVersions.keys}")
    }

    // ---- Local Resource Access ----

    /**
     * Check if a resource exists locally (sandbox first, then assets)
     */
    fun hasResource(path: String): Boolean {
        // 1. Check sandbox (hot-updated version)
        val sandboxFile = File(resourceDir, path)
        if (sandboxFile.exists()) return true

        // 2. Check assets (bundled version)
        return try {
            context.assets.list("$ASSETS_BASE/${path.substringBeforeLast("/")}")
                ?.contains(path.substringAfterLast("/")) == true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Get resource InputStream (sandbox > assets)
     * Returns null if not found
     */
    fun getResourceStream(path: String): InputStream? {
        // 1. Sandbox (hot-updated)
        val sandboxFile = File(resourceDir, path)
        if (sandboxFile.exists()) {
            Logger.d(TAG, "Serving from sandbox: $path")
            return sandboxFile.inputStream()
        }

        // 2. Assets (bundled)
        return try {
            val assetPath = "$ASSETS_BASE/$path"
            context.assets.open(assetPath).also {
                Logger.d(TAG, "Serving from assets: $path")
            }
        } catch (e: Exception) {
            Logger.d(TAG, "Resource not found: $path")
            null
        }
    }

    /**
     * Get MIME type for a file path
     */
    fun getMimeType(path: String): String {
        return when {
            path.endsWith(".html") -> "text/html"
            path.endsWith(".css") -> "text/css"
            path.endsWith(".js") -> "application/javascript"
            path.endsWith(".json") -> "application/json"
            path.endsWith(".png") -> "image/png"
            path.endsWith(".jpg") || path.endsWith(".jpeg") -> "image/jpeg"
            path.endsWith(".gif") -> "image/gif"
            path.endsWith(".svg") -> "image/svg+xml"
            path.endsWith(".ico") -> "image/x-icon"
            path.endsWith(".woff") -> "font/woff"
            path.endsWith(".woff2") -> "font/woff2"
            path.endsWith(".ttf") -> "font/ttf"
            else -> "application/octet-stream"
        }
    }

    // ---- Version Management ----

    /**
     * Get local version of a module
     */
    fun getLocalVersion(moduleId: String): String {
        return localVersions[moduleId] ?: "0.0.0"
    }

    /**
     * Get all local module versions
     */
    fun getAllVersions(): Map<String, String> = localVersions.toMap()

    /**
     * Load local versions from sandbox
     */
    private fun loadLocalVersions() {
        val versionFile = File(resourceDir, VERSION_FILE)
        if (versionFile.exists()) {
            try {
                val content = versionFile.readText()
                val versions = json.decodeFromString<Map<String, String>>(content)
                localVersions.putAll(versions)
            } catch (e: Exception) {
                Logger.e(TAG, "Failed to load versions", e)
            }
        }

        // Also check assets for bundled module versions (coconut-web/<moduleId>/manifest.json)
        for (moduleDir in bundledModuleDirs()) {
            try {
                val manifest = context.assets.open("$ASSETS_BASE/$moduleDir/$MANIFEST_FILE")
                    .bufferedReader().readText()
                val moduleVersion = json.decodeFromString<ModuleVersion>(manifest)
                if (compareVersions(moduleVersion.version, localVersions[moduleVersion.moduleId] ?: "0.0.0") > 0) {
                    localVersions[moduleVersion.moduleId] = moduleVersion.version
                }
            } catch (e: Exception) {
                // No bundled manifest in this dir, that's OK
            }
        }
    }

    private fun bundledModuleDirs(): List<String> = try {
        context.assets.list(ASSETS_BASE)?.toList() ?: emptyList()
    } catch (e: Exception) {
        emptyList()
    }

    // ---- Hot Update ----

    /**
     * Fetch the remote manifest and decide whether an update is available.
     *
     * Current version = max(sandbox version.json entry, bundled manifest version);
     * `available` only when remote is strictly greater.
     */
    suspend fun checkUpdate(moduleId: String, manifestUrl: String): UpdateCheckResult =
        withContext(Dispatchers.IO) {
            val manifest = fetchManifest(manifestUrl)
            if (manifest == null) {
                return@withContext UpdateCheckResult(
                    available = false,
                    currentVersion = getLocalVersion(moduleId),
                    remoteVersion = "",
                    error = "Failed to fetch or parse manifest: $manifestUrl"
                )
            }
            if (manifest.moduleId != moduleId) {
                return@withContext UpdateCheckResult(
                    available = false,
                    currentVersion = getLocalVersion(moduleId),
                    remoteVersion = manifest.version,
                    error = "moduleId mismatch: expected=$moduleId got=${manifest.moduleId}"
                )
            }
            val available = decideUpdate(
                sandboxVersion = localVersions[moduleId],
                bundledVersion = bundledManifestVersion(moduleId),
                remoteVersion = manifest.version
            )
            UpdateCheckResult(
                available = available,
                currentVersion = getLocalVersion(moduleId),
                remoteVersion = manifest.version,
                manifest = manifest
            )
        }

    /**
     * Download every manifest file, verify its md5, then atomically swap the
     * module directory. On any failure the staging directory is removed and
     * the previously installed version is left untouched.
     */
    suspend fun performUpdate(manifest: RemoteManifest, baseUrl: String): UpdateResult =
        withContext(Dispatchers.IO) {
            val moduleId = manifest.moduleId

            val validationError = validateManifest(manifest)
            if (validationError != null) {
                return@withContext UpdateResult(false, moduleId, manifest.version, validationError)
            }

            val staging = File(resourceDir, stagingDirName(moduleId))
            staging.deleteRecursively()
            staging.mkdirs()

            try {
                for (file in manifest.files) {
                    val target = File(staging, file)
                    target.parentFile?.mkdirs()
                    if (!downloadToFile(joinUrl(baseUrl, file), target)) {
                        throw IllegalStateException("Download failed: $file")
                    }
                    val expected = manifest.fileHashes[file]!!.lowercase()
                    val actual = calculateMD5(target)
                    if (actual != expected) {
                        throw IllegalStateException("MD5 mismatch for $file: expected=$expected actual=$actual")
                    }
                }

                swapStaged(resourceDir, moduleId)
                localVersions[moduleId] = manifest.version
                saveVersions()
                Logger.i(TAG, "Update applied: $moduleId v${manifest.version}")
                UpdateResult(true, moduleId, manifest.version)
            } catch (e: Exception) {
                Logger.e(TAG, "performUpdate failed", e)
                staging.deleteRecursively()
                UpdateResult(false, moduleId, manifest.version, e.message)
            }
        }

    /**
     * Remove the sandbox copy of a module and its version entry, falling back
     * to the bundled package. Re-merges the bundled version into memory so
     * [getLocalVersion] reports the bundled version after rollback.
     */
    suspend fun rollback(moduleId: String): Boolean = withContext(Dispatchers.IO) {
        val moduleDir = File(resourceDir, moduleId)
        if (moduleDir.exists() && !moduleDir.deleteRecursively()) {
            Logger.e(TAG, "rollback: failed to delete $moduleDir")
            return@withContext false
        }
        localVersions.remove(moduleId)
        saveVersions()
        loadLocalVersions()
        Logger.i(TAG, "Rolled back $moduleId to bundled version")
        true
    }

    private suspend fun fetchManifest(manifestUrl: String): RemoteManifest? {
        val tmp = File.createTempFile("coconut_manifest", ".json")
        return try {
            if (!downloadToFile(manifestUrl, tmp)) return null
            json.decodeFromString<RemoteManifest>(tmp.readText())
        } catch (e: Exception) {
            Logger.e(TAG, "Failed to fetch manifest", e)
            null
        } finally {
            tmp.delete()
        }
    }

    private fun bundledManifestVersion(moduleId: String): String? {
        for (moduleDir in bundledModuleDirs()) {
            try {
                val content = context.assets.open("$ASSETS_BASE/$moduleDir/$MANIFEST_FILE")
                    .bufferedReader().readText()
                val manifest = json.decodeFromString<ModuleVersion>(content)
                if (manifest.moduleId == moduleId) return manifest.version
            } catch (e: Exception) {
                // try next dir
            }
        }
        return null
    }

    internal fun stagingDirName(moduleId: String): String = ".staging_$moduleId"

    private fun joinUrl(baseUrl: String, path: String): String =
        baseUrl.trimEnd('/') + "/" + path

    // ---- Helpers ----

    internal suspend fun downloadToFile(urlStr: String, targetFile: File): Boolean =
        withContext(Dispatchers.IO) {
            try {
                val url = URL(urlStr)
                val connection = url.openConnection() as HttpURLConnection
                connection.connectTimeout = 15000
                connection.readTimeout = 30000

                if (connection.responseCode != HttpURLConnection.HTTP_OK) {
                    return@withContext false
                }

                connection.inputStream.use { input ->
                    FileOutputStream(targetFile).use { output ->
                        val buffer = ByteArray(8192)
                        var read: Int
                        while (input.read(buffer).also { read = it } != -1) {
                            output.write(buffer, 0, read)
                        }
                    }
                }
                true
            } catch (e: Exception) {
                Logger.e(TAG, "Download error: $urlStr", e)
                false
            }
        }

    internal fun calculateMD5(file: File): String {
        val md = MessageDigest.getInstance("MD5")
        file.inputStream().use { fis ->
            val buffer = ByteArray(8192)
            var read: Int
            while (fis.read(buffer).also { read = it } != -1) {
                md.update(buffer, 0, read)
            }
        }
        return md.digest().joinToString("") { "%02x".format(it) }
    }

    private fun saveVersions() {
        val versionFile = File(resourceDir, VERSION_FILE)
        versionFile.writeText(json.encodeToString(
            kotlinx.serialization.serializer<Map<String, String>>(),
            localVersions.toMap()
        ))
    }

    companion object {
        private const val TAG = "ResourceManager"
        private const val ASSETS_BASE = "coconut-web"       // assets subdirectory for bundled H5
        private const val VERSION_FILE = "version.json"     // Version info file name
        private const val MANIFEST_FILE = "manifest.json"   // Resource manifest

        /**
         * Compare two dotted version strings. Non-numeric segments parse as 0.
         * Returns < 0 / 0 / > 0 following String.compareTo conventions.
         */
        fun compareVersions(v1: String, v2: String): Int {
            val parts1 = v1.split(".").map { it.toIntOrNull() ?: 0 }
            val parts2 = v2.split(".").map { it.toIntOrNull() ?: 0 }
            for (i in 0 until maxOf(parts1.size, parts2.size)) {
                val p1 = parts1.getOrElse(i) { 0 }
                val p2 = parts2.getOrElse(i) { 0 }
                if (p1 != p2) return p1 - p2
            }
            return 0
        }

        /**
         * Reject paths that could escape the module directory when written
         * from a (potentially hostile) remote manifest.
         */
        fun isSafePackagePath(path: String): Boolean {
            if (path.isEmpty() || path.startsWith("/") || path.contains("\\")) return false
            return path.split("/").all { it.isNotEmpty() && it != "." && it != ".." }
        }

        /**
         * An update is available only when the remote version is strictly
         * greater than both the sandbox version and the bundled version.
         */
        fun decideUpdate(
            sandboxVersion: String?,
            bundledVersion: String?,
            remoteVersion: String
        ): Boolean {
            var current = "0.0.0"
            for (v in listOfNotNull(sandboxVersion, bundledVersion)) {
                if (compareVersions(v, current) > 0) current = v
            }
            return compareVersions(remoteVersion, current) > 0
        }

        /**
         * Fail-closed manifest validation: non-empty file list, every file
         * path safe, every file covered by a non-blank md5 entry.
         * Returns an error message, or null when the manifest is valid.
         */
        fun validateManifest(manifest: RemoteManifest): String? {
            if (manifest.files.isEmpty()) return "manifest has no files"
            for (file in manifest.files) {
                if (!isSafePackagePath(file)) return "unsafe package path: $file"
                val hash = manifest.fileHashes[file]
                if (hash == null || hash.isBlank()) return "missing fileHashes entry: $file"
            }
            return null
        }

        /**
         * Verify that every manifest file present in [stagingDir] matches its
         * expected md5. Returns the first offending file path, or null when
         * all hashes match. Missing files count as mismatches.
         */
        fun verifyDownloaded(stagingDir: File, manifest: RemoteManifest): String? {
            for (file in manifest.files) {
                val f = File(stagingDir, file)
                if (!f.exists()) return file
                if (md5Hex(f.readBytes()) != manifest.fileHashes[file]?.lowercase()) return file
            }
            return null
        }

        /**
         * Atomic swap: drop the current module directory and rename the
         * staging directory into its place. Throws on failure.
         */
        fun swapStaged(sandboxRoot: File, moduleId: String) {
            val moduleDir = File(sandboxRoot, moduleId)
            val staging = File(sandboxRoot, ".staging_$moduleId")
            if (moduleDir.exists() && !moduleDir.deleteRecursively()) {
                throw IllegalStateException("swap failed: cannot remove old module dir $moduleDir")
            }
            if (!staging.renameTo(moduleDir)) {
                throw IllegalStateException("swap failed: cannot rename $staging to $moduleDir")
            }
        }

        fun md5Hex(bytes: ByteArray): String =
            MessageDigest.getInstance("MD5").digest(bytes).joinToString("") { "%02x".format(it) }
    }
}
