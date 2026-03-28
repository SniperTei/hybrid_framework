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
 * - Supports hot update: download zip → extract to sandbox → serve from sandbox
 * - Version management: local version vs remote version
 * - MD5 integrity check
 */
class OfflineResourceManager(private val context: Context) {

    private val json = Json { ignoreUnknownKeys = true }

    // Resource root in sandbox
    private val resourceDir = File(context.filesDir, "coconut_resources")

    // Module versions: moduleId -> version string
    private val localVersions = ConcurrentHashMap<String, String>()

    companion object {
        private const val TAG = "ResourceManager"
        private const val ASSETS_BASE = "coconut-web"       // assets subdirectory for bundled H5
        private const val VERSION_FILE = "version.json"     // Version info file name
        private const val MANIFEST_FILE = "manifest.json"   // Resource manifest
    }

    // ---- Data Models ----

    @Serializable
    data class ModuleVersion(
        val moduleId: String = "",
        val version: String = "0.0.0",
        val files: List<String> = emptyList(),
        val md5: String = ""
    )

    @Serializable
    data class UpdateInfo(
        val moduleId: String = "",
        val version: String = "",
        val downloadUrl: String = "",
        val md5: String = "",
        val fileSize: Long = 0,
        val releaseNotes: String = ""
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

        // Also check assets for bundled module versions
        try {
            val manifest = context.assets.open("$ASSETS_BASE/$MANIFEST_FILE").bufferedReader().readText()
            val moduleVersion = json.decodeFromString<ModuleVersion>(manifest)
            if (!localVersions.containsKey(moduleVersion.moduleId) ||
                compareVersions(moduleVersion.version, localVersions[moduleVersion.moduleId] ?: "0.0.0") > 0
            ) {
                localVersions[moduleVersion.moduleId] = moduleVersion.version
            }
        } catch (e: Exception) {
            // No bundled manifest, that's OK
        }
    }

    // ---- Hot Update ----

    /**
     * Download and apply a resource update
     *
     * @param updateInfo Update info from server
     * @param onProgress Progress callback (0-100)
     * @return true if update applied successfully
     */
    suspend fun applyUpdate(
        updateInfo: UpdateInfo,
        onProgress: ((Int) -> Unit)? = null
    ): Boolean = withContext(Dispatchers.IO) {
        try {
            Logger.i(TAG, "Downloading update: ${updateInfo.moduleId} v${updateInfo.version}")

            // 1. Download zip to temp
            val tempFile = File(context.cacheDir, "update_${updateInfo.moduleId}.zip")
            val downloaded = downloadFile(updateInfo.downloadUrl, tempFile, onProgress)
            if (!downloaded) {
                Logger.e(TAG, "Download failed")
                return@withContext false
            }

            // 2. MD5 check
            if (updateInfo.md5.isNotEmpty()) {
                val actualMd5 = calculateMD5(tempFile)
                if (actualMd5 != updateInfo.md5) {
                    Logger.e(TAG, "MD5 mismatch: expected=${updateInfo.md5}, actual=$actualMd5")
                    tempFile.delete()
                    return@withContext false
                }
            }

            // 3. Extract to sandbox
            val moduleDir = File(resourceDir, updateInfo.moduleId)
            if (moduleDir.exists()) {
                moduleDir.deleteRecursively()
            }
            moduleDir.mkdirs()

            extractZip(tempFile, moduleDir)

            // 4. Update version
            localVersions[updateInfo.moduleId] = updateInfo.version
            saveVersions()

            // 5. Cleanup temp
            tempFile.delete()

            Logger.i(TAG, "Update applied: ${updateInfo.moduleId} v${updateInfo.version}")
            true
        } catch (e: Exception) {
            Logger.e(TAG, "Failed to apply update", e)
            false
        }
    }

    /**
     * Check for updates by comparing local version with remote
     */
    fun needsUpdate(moduleId: String, remoteVersion: String): Boolean {
        val local = localVersions[moduleId] ?: "0.0.0"
        return compareVersions(remoteVersion, local) > 0
    }

    // ---- Helpers ----

    private suspend fun downloadFile(
        urlStr: String,
        targetFile: File,
        onProgress: ((Int) -> Unit)?
    ): Boolean = withContext(Dispatchers.IO) {
        try {
            val url = URL(urlStr)
            val connection = url.openConnection() as HttpURLConnection
            connection.connectTimeout = 15000
            connection.readTimeout = 30000

            if (connection.responseCode != HttpURLConnection.HTTP_OK) {
                return@withContext false
            }

            val contentLength = connection.contentLength.toLong()
            var bytesRead = 0L

            connection.inputStream.use { input ->
                FileOutputStream(targetFile).use { output ->
                    val buffer = ByteArray(8192)
                    var read: Int
                    while (input.read(buffer).also { read = it } != -1) {
                        output.write(buffer, 0, read)
                        bytesRead += read
                        if (contentLength > 0 && onProgress != null) {
                            val progress = ((bytesRead * 100) / contentLength).toInt()
                            onProgress(progress)
                        }
                    }
                }
            }
            true
        } catch (e: Exception) {
            Logger.e(TAG, "Download error: $urlStr", e)
            false
        }
    }

    private fun extractZip(zipFile: File, targetDir: File) {
        java.util.zip.ZipInputStream(zipFile.inputStream()).use { zis ->
            var entry = zis.nextEntry
            while (entry != null) {
                val outFile = File(targetDir, entry.name)
                if (entry.isDirectory) {
                    outFile.mkdirs()
                } else {
                    outFile.parentFile?.mkdirs()
                    FileOutputStream(outFile).use { fos ->
                        val buffer = ByteArray(8192)
                        var len: Int
                        while (zis.read(buffer).also { len = it } > 0) {
                            fos.write(buffer, 0, len)
                        }
                    }
                }
                zis.closeEntry()
                entry = zis.nextEntry
            }
        }
    }

    private fun calculateMD5(file: File): String {
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

    private fun compareVersions(v1: String, v2: String): Int {
        val parts1 = v1.split(".").map { it.toIntOrNull() ?: 0 }
        val parts2 = v2.split(".").map { it.toIntOrNull() ?: 0 }
        for (i in 0 until maxOf(parts1.size, parts2.size)) {
            val p1 = parts1.getOrElse(i) { 0 }
            val p2 = parts2.getOrElse(i) { 0 }
            if (p1 != p2) return p1 - p2
        }
        return 0
    }
}
