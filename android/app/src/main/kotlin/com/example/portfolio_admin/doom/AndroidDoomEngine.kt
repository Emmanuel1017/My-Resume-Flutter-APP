package com.example.portfolio_admin.doom

import android.graphics.Bitmap
import android.util.Log
import doom.CVarManager
import doom.ConfigManager
import doom.DoomMain
import doom.event_t
import doom.evtype_t
import g.Signals
import g.Signals.ScanCode
import java.awt.image.BufferedImage
import java.awt.image.DataBufferInt

/**
 * Android-specific DOOM engine wrapper around kocoa-doom.
 *
 * Replaces the desktop Engine.kt by:
 * - Skipping AWT window creation
 * - Running the game loop on a background thread
 * - Exposing frame pixels via getFrameBitmap()
 * - Accepting key events via postKey()
 */
class AndroidDoomEngine(private val wadPath: String) {

    companion object {
        private const val TAG = "AndroidDoomEngine"
        const val DOOM_WIDTH = 320
        const val DOOM_HEIGHT = 200

        @Volatile
        var instance: AndroidDoomEngine? = null
            private set
    }

    private var doom: DoomMain<*, *>? = null
    private var cvm: CVarManager? = null
    private var cm: ConfigManager? = null
    private var gameThread: Thread? = null

    @Volatile
    var running = false
        private set

    @Volatile
    private var frameReady = false

    private val frameLock = Object()
    private var frameBitmap: Bitmap? = null
    private var framePixels: IntArray? = null

    fun start() {
        if (running) return
        instance = this
        running = true

        // Register frame callback with kocoa-doom engine
        mochadoom.Engine.androidFrameCallback = { onFrameReady() }

        gameThread = Thread({
            try {
                Log.d(TAG, "Starting kocoa-doom with WAD: $wadPath")

                // Set the working directory to app's files dir for config file I/O
                val filesDir = android.os.Environment.getDataDirectory().absolutePath
                val appFilesDir = wadPath.substringBeforeLast("/doom_wads")
                System.setProperty("user.dir", appFilesDir)

                cvm = CVarManager(listOf("-iwad", wadPath, "-width", "$DOOM_WIDTH", "-height", "$DOOM_HEIGHT"))

                // Register CVM with Engine companion before ConfigManager accesses it
                mochadoom.Engine.androidCVM = cvm

                cm = ConfigManager()
                mochadoom.Engine.androidCM = cm

                doom = DoomMain<Any, Any>()

                Log.d(TAG, "DoomMain initialized, entering game loop")

                doom!!.setupLoop()
            } catch (e: Exception) {
                Log.e(TAG, "DOOM engine error", e)
            } finally {
                running = false
                mochadoom.Engine.androidFrameCallback = null
                mochadoom.Engine.androidCVM = null
                mochadoom.Engine.androidCM = null
                instance = null
            }
        }, "kocoa-doom-game").apply {
            isDaemon = true
            start()
        }
    }

    fun stop() {
        running = false
        gameThread?.interrupt()
        gameThread = null
        instance = null
        frameBitmap?.recycle()
        frameBitmap = null
    }

    /**
     * Called from Engine.updateFrame() via our hook.
     * Captures the current frame pixels from the graphic system.
     */
    private var frameCount = 0

    fun onFrameReady() {
        val dm = doom ?: return

        try {
            val screenImage = dm.graphicSystem.getScreenImage()
            if (screenImage == null) {
                if (frameCount < 3) Log.w(TAG, "getScreenImage() returned null")
                return
            }

            if (frameCount < 3) {
                Log.d(TAG, "Frame image type: ${screenImage::class.java.name}")
            }

            if (screenImage is BufferedImage) {
                val raster = screenImage.raster
                val dataBuffer = raster.dataBuffer

                if (frameCount < 3) {
                    Log.d(TAG, "DataBuffer type: ${dataBuffer::class.java.name}, size=${dataBuffer.size}")
                }

                val width = screenImage.getWidth(null)
                    val height = screenImage.getHeight(null)

                    if (dataBuffer is DataBufferInt) {
                        val pixels = dataBuffer.data

                        if (frameCount == 0) {
                            Log.d(TAG, "First frame (int): ${width}x${height}, pixels=${pixels.size}")
                        }
                        frameCount++

                        synchronized(frameLock) {
                            if (frameBitmap == null || frameBitmap!!.width != width || frameBitmap!!.height != height) {
                                frameBitmap?.recycle()
                                frameBitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                                framePixels = IntArray(width * height)
                            }

                            System.arraycopy(pixels, 0, framePixels!!, 0, pixels.size.coerceAtMost(framePixels!!.size))
                            frameBitmap!!.setPixels(framePixels!!, 0, width, 0, 0, width, height)
                            frameReady = true
                        }
                    } else if (dataBuffer is java.awt.image.DataBufferByte) {
                        // Indexed color mode — convert via BufferedImage's color model
                        val byteData = dataBuffer.data
                        val colorModel = screenImage.colorModel

                        if (frameCount == 0) {
                            Log.d(TAG, "First frame (byte/indexed): ${width}x${height}, bytes=${byteData.size}")
                        }
                        frameCount++

                        synchronized(frameLock) {
                            if (frameBitmap == null || frameBitmap!!.width != width || frameBitmap!!.height != height) {
                                frameBitmap?.recycle()
                                frameBitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                                framePixels = IntArray(width * height)
                            }

                            // Convert indexed bytes to ARGB via the color model
                            for (i in byteData.indices.take(framePixels!!.size)) {
                                framePixels!![i] = colorModel.getRGB(byteData[i].toInt() and 0xFF)
                            }

                            frameBitmap!!.setPixels(framePixels!!, 0, width, 0, 0, width, height)
                            frameReady = true
                        }
                    }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error capturing frame", e)
        }
    }

    /**
     * Get the latest rendered frame as a Bitmap.
     * Returns null if no frame is ready yet.
     */
    fun getFrameBitmap(): Bitmap? {
        if (!frameReady) return null
        synchronized(frameLock) {
            return frameBitmap
        }
    }

    /**
     * Post a key event to the DOOM engine using VK_ code.
     * Maps the VK code to the appropriate ScanCode and uses pre-built events.
     */
    fun postKeyCode(vkCode: Int, pressed: Boolean) {
        val dm = doom ?: return

        // Look up ScanCode from VK code using the Signals map
        val scOrdinal = g.Signals.map[vkCode].toInt() and 0xFF
        if (scOrdinal == 0) return

        val sc = ScanCode.v[scOrdinal]
        val ev = if (pressed) sc.doomEventDown else sc.doomEventUp
        dm.PostEvent(ev)
    }
}
