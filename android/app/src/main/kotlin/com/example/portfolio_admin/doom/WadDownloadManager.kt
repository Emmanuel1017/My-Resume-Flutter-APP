package com.example.portfolio_admin.doom

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.zip.ZipInputStream

/**
 * Downloads DOOM WAD files from GitHub assets and caches them locally.
 *
 * GitHub assets structure:
 * - doom.jsdos (contains DOOM1.WAD)
 * - doom2.jsdos (contains DOOM2.WAD)
 *
 * .jsdos files are ZIP archives containing the WAD file.
 */
class WadDownloadManager(private val context: Context) {

    companion object {
        private const val GITHUB_BASE_URL =
            "https://raw.githubusercontent.com/Emmanuel1017/portfolio-admin/main/assets/doom"

        private const val DOOM1_JSDOS_URL = "$GITHUB_BASE_URL/doom.jsdos"
        private const val DOOM2_JSDOS_URL = "$GITHUB_BASE_URL/doom2.jsdos"

        private const val DOOM1_WAD_NAME = "DOOM1.WAD"
        private const val DOOM2_WAD_NAME = "DOOM2.WAD"
    }

    /**
     * Download progress callback.
     * @param bytesDownloaded Current bytes downloaded
     * @param totalBytes Total file size in bytes
     * @param percentComplete Progress as 0-100
     */
    data class DownloadProgress(
        val bytesDownloaded: Long,
        val totalBytes: Long,
        val percentComplete: Int
    )

    private val cacheDir: File by lazy {
        File(context.filesDir, "doom_wads").apply {
            if (!exists()) mkdirs()
        }
    }

    /**
     * Check if a WAD file is already cached.
     */
    fun isWadCached(game: DoomGame): Boolean {
        val wadFile = getWadFile(game)
        return wadFile.exists() && wadFile.length() > 0
    }

    /**
     * Extract WAD from app assets (bundled .jsdos files).
     */
    suspend fun extractFromAssets(
        game: DoomGame,
        onProgress: ((DownloadProgress) -> Unit)? = null
    ): Result<File> = withContext(Dispatchers.IO) {
        try {
            android.util.Log.d("DOOM", "[extractFromAssets] Starting for game: $game")

            val wadFile = getWadFile(game)
            android.util.Log.d("DOOM", "[extractFromAssets] WAD file path: ${wadFile.absolutePath}")

            // If already cached, return it
            if (isWadCached(game)) {
                android.util.Log.d("DOOM", "[extractFromAssets] WAD already cached!")
                return@withContext Result.success(wadFile)
            }

            val assetName = when (game) {
                DoomGame.DOOM1 -> "flutter_assets/assets/doom/doom.jsdos"
                DoomGame.DOOM2 -> "flutter_assets/assets/doom/doom2.jsdos"
            }
            android.util.Log.d("DOOM", "[extractFromAssets] Opening asset: $assetName")

            // Open asset as stream
            val inputStream = context.assets.open(assetName)
            val totalBytes = inputStream.available().toLong()
            android.util.Log.d("DOOM", "[extractFromAssets] Asset size: $totalBytes bytes")

            var extractedBytes = 0L

            // Extract directly from asset ZIP
            val tempFile = File(cacheDir, "${game.name}.jsdos.tmp")
            android.util.Log.d("DOOM", "[extractFromAssets] Temp file: ${tempFile.absolutePath}")

            inputStream.use { input ->
                FileOutputStream(tempFile).use { output ->
                    val buffer = ByteArray(8192)
                    var bytesRead: Int

                    while (input.read(buffer).also { bytesRead = it } != -1) {
                        output.write(buffer, 0, bytesRead)
                        extractedBytes += bytesRead

                        onProgress?.invoke(
                            DownloadProgress(
                                bytesDownloaded = extractedBytes,
                                totalBytes = totalBytes,
                                percentComplete = ((extractedBytes * 100) / totalBytes).toInt()
                            )
                        )
                    }
                }
            }

            android.util.Log.d("DOOM", "[extractFromAssets] Asset copied. Extracting WAD from ZIP...")

            // Extract WAD from the copied jsdos file
            val wadExtracted = extractWadFromZip(tempFile, wadFile)
            tempFile.delete()

            if (!wadExtracted) {
                android.util.Log.e("DOOM", "[extractFromAssets] Failed to extract WAD from ZIP")
                return@withContext Result.failure(
                    Exception("Failed to extract WAD from asset - no .WAD file found in archive")
                )
            }

            android.util.Log.d("DOOM", "[extractFromAssets] Success! WAD extracted to: ${wadFile.absolutePath}")
            Result.success(wadFile)

        } catch (e: Exception) {
            android.util.Log.e("DOOM", "[extractFromAssets] Exception: ${e.message}", e)
            Result.failure(e)
        }
    }

    /**
     * Get the cached WAD file path.
     */
    fun getWadFile(game: DoomGame): File {
        val wadName = when (game) {
            DoomGame.DOOM1 -> DOOM1_WAD_NAME
            DoomGame.DOOM2 -> DOOM2_WAD_NAME
        }
        return File(cacheDir, wadName)
    }

    /**
     * Download and extract WAD file from GitHub.
     *
     * @param game Which game to download
     * @param onProgress Progress callback
     * @return The extracted WAD file
     */
    suspend fun downloadWad(
        game: DoomGame,
        onProgress: ((DownloadProgress) -> Unit)? = null
    ): Result<File> = withContext(Dispatchers.IO) {
        try {
            val jsdosUrl = when (game) {
                DoomGame.DOOM1 -> DOOM1_JSDOS_URL
                DoomGame.DOOM2 -> DOOM2_JSDOS_URL
            }

            val wadFile = getWadFile(game)

            // If already cached, return it
            if (isWadCached(game)) {
                return@withContext Result.success(wadFile)
            }

            // Download .jsdos file (which is a ZIP)
            val url = URL(jsdosUrl)
            val connection = url.openConnection() as HttpURLConnection
            connection.connect()

            if (connection.responseCode != HttpURLConnection.HTTP_OK) {
                return@withContext Result.failure(
                    Exception("Download failed: HTTP ${connection.responseCode}")
                )
            }

            val totalBytes = connection.contentLength.toLong()
            var downloadedBytes = 0L

            // Download to temporary file
            val tempFile = File(cacheDir, "${game.name}.jsdos.tmp")

            connection.inputStream.use { input ->
                FileOutputStream(tempFile).use { output ->
                    val buffer = ByteArray(8192)
                    var bytesRead: Int

                    while (input.read(buffer).also { bytesRead = it } != -1) {
                        output.write(buffer, 0, bytesRead)
                        downloadedBytes += bytesRead

                        onProgress?.invoke(
                            DownloadProgress(
                                bytesDownloaded = downloadedBytes,
                                totalBytes = totalBytes,
                                percentComplete = ((downloadedBytes * 100) / totalBytes).toInt()
                            )
                        )
                    }
                }
            }

            // Extract WAD from ZIP (jsdos file is a ZIP archive)
            val wadExtracted = extractWadFromZip(tempFile, wadFile)

            // Clean up temp file
            tempFile.delete()

            if (!wadExtracted) {
                return@withContext Result.failure(
                    Exception("Failed to extract WAD from jsdos archive")
                )
            }

            Result.success(wadFile)

        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Extract WAD file from .jsdos ZIP archive.
     */
    private fun extractWadFromZip(jsdosFile: File, outputWadFile: File): Boolean {
        try {
            ZipInputStream(jsdosFile.inputStream()).use { zip ->
                var entry = zip.nextEntry

                while (entry != null) {
                    // Look for .WAD file in the archive
                    if (entry.name.uppercase().endsWith(".WAD")) {
                        FileOutputStream(outputWadFile).use { output ->
                            val buffer = ByteArray(8192)
                            var bytesRead: Int

                            while (zip.read(buffer).also { bytesRead = it } != -1) {
                                output.write(buffer, 0, bytesRead)
                            }
                        }
                        return true
                    }
                    entry = zip.nextEntry
                }
            }
            return false
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }

    /**
     * Delete cached WAD file (for re-download).
     */
    fun clearCache(game: DoomGame) {
        getWadFile(game).delete()
    }

    /**
     * Delete all cached WAD files.
     */
    fun clearAllCache() {
        cacheDir.listFiles()?.forEach { it.delete() }
    }

    /**
     * Get total cache size in bytes.
     */
    fun getCacheSize(): Long {
        return cacheDir.listFiles()?.sumOf { it.length() } ?: 0L
    }
}

/**
 * Available DOOM games.
 */
enum class DoomGame {
    DOOM1,
    DOOM2
}
