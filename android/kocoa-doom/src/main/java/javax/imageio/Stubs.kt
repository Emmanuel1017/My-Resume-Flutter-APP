@file:Suppress("UNUSED_PARAMETER", "unused")
package javax.imageio

import java.awt.image.BufferedImage
import java.io.File
import java.io.InputStream
import java.io.OutputStream
import java.net.URL

/**
 * Stub for javax.imageio.ImageIO - all methods are no-ops or return null/defaults.
 */
object ImageIO {
    @JvmStatic
    fun read(input: File?): BufferedImage? = null

    @JvmStatic
    fun read(input: InputStream?): BufferedImage? = null

    @JvmStatic
    fun read(input: URL?): BufferedImage? = null

    @JvmStatic
    fun write(im: BufferedImage?, formatName: String?, output: File?): Boolean = true

    @JvmStatic
    fun write(im: BufferedImage?, formatName: String?, output: OutputStream?): Boolean = true

    @JvmStatic
    fun getReaderFormatNames(): Array<String> = arrayOf("png", "jpg", "gif", "bmp")

    @JvmStatic
    fun getWriterFormatNames(): Array<String> = arrayOf("png", "jpg", "gif", "bmp")

    @JvmStatic
    fun getReaderMIMETypes(): Array<String> = arrayOf("image/png", "image/jpeg", "image/gif", "image/bmp")

    @JvmStatic
    fun getWriterMIMETypes(): Array<String> = arrayOf("image/png", "image/jpeg", "image/gif", "image/bmp")

    @JvmStatic
    fun createImageInputStream(input: Any?): Any? = null

    @JvmStatic
    fun createImageOutputStream(output: Any?): Any? = null

    @JvmStatic
    fun getImageReadersByFormatName(formatName: String?): Iterator<Any> = emptyList<Any>().iterator()

    @JvmStatic
    fun getImageWritersByFormatName(formatName: String?): Iterator<Any> = emptyList<Any>().iterator()

    @JvmStatic
    fun setUseCache(useCache: Boolean) {}

    @JvmStatic
    fun getUseCache(): Boolean = false

    @JvmStatic
    fun setCacheDirectory(cacheDirectory: File?) {}

    @JvmStatic
    fun getCacheDirectory(): File? = null
}
