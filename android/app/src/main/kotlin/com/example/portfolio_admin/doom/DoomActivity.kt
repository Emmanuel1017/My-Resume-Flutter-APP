package com.example.portfolio_admin.doom

import android.content.Context
import android.content.Intent
import android.content.pm.ActivityInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.os.Bundle
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import g.Signals.ScanCode
import kotlinx.coroutines.launch

/**
 * Native DOOM Activity powered by kocoa-doom engine.
 *
 * Renders the game to a SurfaceView via the kocoa-doom Kotlin source port.
 * Touch controls are overlaid for mobile input.
 */
class DoomActivity : AppCompatActivity() {

    companion object {
        private const val EXTRA_GAME = "game"
        private const val TAG = "DoomActivity"

        fun launch(context: Context, game: DoomGame) {
            val intent = Intent(context, DoomActivity::class.java).apply {
                putExtra(EXTRA_GAME, game.name)
            }
            context.startActivity(intent)
        }
    }

    private lateinit var wadManager: WadDownloadManager
    private lateinit var game: DoomGame
    private var engine: AndroidDoomEngine? = null
    @Volatile private var finishing = false

    private lateinit var loadingContainer: FrameLayout
    private lateinit var progressBar: ProgressBar
    private lateinit var statusText: TextView
    private lateinit var gameContainer: FrameLayout

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE

        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_FULLSCREEN
            or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
            or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
        )
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        // Re-apply immersive on any system UI change to prevent rotation flicker
        @Suppress("DEPRECATION")
        window.decorView.setOnSystemUiVisibilityChangeListener {
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            )
        }

        val gameName = intent.getStringExtra(EXTRA_GAME) ?: "DOOM1"
        game = try {
            DoomGame.valueOf(gameName)
        } catch (e: IllegalArgumentException) {
            DoomGame.DOOM1
        }

        wadManager = WadDownloadManager(this)

        setupUI()
        initializeGame()
    }

    private fun setupUI() {
        val rootLayout = FrameLayout(this).apply {
            setBackgroundColor(Color.BLACK)
        }

        loadingContainer = FrameLayout(this).apply {
            visibility = View.VISIBLE
        }

        progressBar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            isIndeterminate = false
            max = 100
        }

        statusText = TextView(this).apply {
            text = "Initializing DOOM..."
            textSize = 18f
            setTextColor(0xFFc41e1e.toInt())
            textAlignment = View.TEXT_ALIGNMENT_CENTER
        }

        val loadingLayout = FrameLayout(this).apply {
            setPadding(64, 32, 64, 32)
        }

        loadingLayout.addView(statusText, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            topMargin = 200
        })

        loadingLayout.addView(progressBar, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            topMargin = 300
        })

        loadingContainer.addView(loadingLayout)

        gameContainer = FrameLayout(this).apply {
            visibility = View.GONE
        }

        rootLayout.addView(gameContainer, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ))

        rootLayout.addView(loadingContainer, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ))

        setContentView(rootLayout)
    }

    private fun initializeGame() {
        lifecycleScope.launch {
            try {
                updateStatus("Checking for cached WAD file...")

                if (!wadManager.isWadCached(game)) {
                    updateStatus("Extracting ${game.name} from assets...")

                    val result = wadManager.extractFromAssets(game) { progress ->
                        runOnUiThread {
                            progressBar.progress = progress.percentComplete
                            updateStatus(
                                "Extracting ${game.name}...\n" +
                                "${progress.bytesDownloaded / 1024 / 1024} MB / " +
                                "${progress.totalBytes / 1024 / 1024} MB"
                            )
                        }
                    }

                    if (result.isFailure) {
                        showError("Extraction failed: ${result.exceptionOrNull()?.message}")
                        return@launch
                    }
                }

                val wadFile = wadManager.getWadFile(game)
                updateStatus("WAD loaded! Starting native DOOM engine...")

                startDoomEngine(wadFile.absolutePath)

            } catch (e: Exception) {
                showError("Error: ${e.message}")
            }
        }
    }

    private fun startDoomEngine(wadPath: String) {
        if (finishing) return
        runOnUiThread {
            if (finishing) return@runOnUiThread
            loadingContainer.visibility = View.GONE
            gameContainer.visibility = View.VISIBLE

            try {
                // Kill any existing audio from prior sessions
                javax.sound.midi.MidiSystem.stopAll()
                javax.sound.sampled.AudioSystem.stopAll()

                // Set cache dir for MIDI music playback
                javax.sound.midi.MidiSystem.androidCacheDir = cacheDir

                // Read settings from SharedPreferences (Flutter's shared_preferences plugin)
                val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)

                // Try both with and without "flutter." prefix for compatibility
                val vsync = prefs.getBoolean("flutter.doom_vsync",
                    prefs.getBoolean("doom_vsync", true))
                val frameRate = try {
                    prefs.getInt("flutter.doom_framerate",
                        prefs.getInt("doom_framerate", 60))
                } catch (e: Exception) { 60 }
                val showFps = prefs.getBoolean("flutter.doom_showfps",
                    prefs.getBoolean("doom_showfps", false))
                val smoothScaling = prefs.getBoolean("flutter.doom_smooth",
                    prefs.getBoolean("doom_smooth", true))
                val swipeSensitivity = try {
                    prefs.getInt("flutter.doom_swipe_sensitivity",
                        prefs.getInt("doom_swipe_sensitivity", 8))
                } catch (e: Exception) { 8 }

                engine = AndroidDoomEngine(wadPath)

                val doomSurface = DoomSurfaceView(this, engine!!, vsync, frameRate, showFps, smoothScaling)

                gameContainer.removeAllViews()
                gameContainer.addView(doomSurface, FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT
                ))

                val touchOverlay = DoomTouchControls(this, swipeSensitivity.toFloat()) { scanCode, pressed ->
                    if (scanCode == DoomTouchControls.KEY_CLOSE && pressed) {
                        stopAll()
                        finish()
                    } else {
                        engine?.postKeyCode(scanCode, pressed)
                    }
                }

                gameContainer.addView(touchOverlay, FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT
                ))

                engine!!.start()

            } catch (e: Exception) {
                e.printStackTrace()
                showError("Failed to start DOOM: ${e.message}")
            }
        }
    }

    private fun updateStatus(status: String) {
        runOnUiThread {
            statusText.text = status
        }
    }

    private fun showError(message: String) {
        runOnUiThread {
            Toast.makeText(this, message, Toast.LENGTH_LONG).show()
            finish()
        }
    }

    private fun stopAll() {
        finishing = true
        engine?.stop()
        engine = null
        javax.sound.midi.MidiSystem.stopAll()
        javax.sound.sampled.AudioSystem.stopAll()
    }

    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        stopAll()
        super.onBackPressed()
    }

    override fun onDestroy() {
        super.onDestroy()
        stopAll()
    }
}

/**
 * SurfaceView that blits kocoa-doom frames to the screen.
 * The engine renders frames internally; we poll and draw them.
 */
class DoomSurfaceView(
    context: Context,
    private val engine: AndroidDoomEngine,
    private val vsync: Boolean = true,
    private val targetFps: Int = 60,
    private val showFps: Boolean = false,
    smoothScaling: Boolean = true
) : SurfaceView(context), SurfaceHolder.Callback {

    @Volatile
    private var rendering = false
    private var renderThread: Thread? = null
    private val srcRect = Rect()
    private val dstRect = RectF()
    private val paint = Paint(if (smoothScaling) Paint.FILTER_BITMAP_FLAG else 0)

    private val doomguyBitmap: Bitmap? = try {
        val stream = context.assets.open("flutter_assets/assets/doom/doomguy-face.jpg")
        android.graphics.BitmapFactory.decodeStream(stream).also { stream.close() }
    } catch (_: Exception) { null }

    init {
        holder.addCallback(this)
        isFocusable = true
        isFocusableInTouchMode = true
    }

    private val fpsPaint = Paint().apply {
        color = 0xFF00FF41.toInt()
        textSize = 28f
        isAntiAlias = true
        isFakeBoldText = true
        setShadowLayer(4f, 1f, 1f, 0xFF000000.toInt())
    }

    override fun surfaceCreated(holder: SurfaceHolder) {
        rendering = true
        val frameSleepMs = if (vsync) (1000L / targetFps) else 0L

        renderThread = Thread({
            var frame = 0L
            var fpsFrameCount = 0
            var fpsLastTime = System.currentTimeMillis()
            var currentFps = 0

            while (rendering) {
                val frameStart = System.nanoTime()

                val bitmap = engine.getFrameBitmap()
                if (bitmap != null) {
                    val canvas: Canvas = holder.lockCanvas() ?: continue
                    try {
                        srcRect.set(0, 0, bitmap.width, bitmap.height)
                        dstRect.set(0f, 0f, canvas.width.toFloat(), canvas.height.toFloat())
                        canvas.drawBitmap(bitmap, srcRect, dstRect, paint)

                        if (showFps) {
                            fpsFrameCount++
                            val now = System.currentTimeMillis()
                            if (now - fpsLastTime >= 1000) {
                                currentFps = fpsFrameCount
                                fpsFrameCount = 0
                                fpsLastTime = now
                            }
                            canvas.drawText("$currentFps FPS", 16f, 40f, fpsPaint)
                        }
                    } finally {
                        holder.unlockCanvasAndPost(canvas)
                    }
                } else {
                    val canvas: Canvas = holder.lockCanvas() ?: continue
                    frame++
                    drawLoadingScreen(canvas, frame)
                    holder.unlockCanvasAndPost(canvas)
                }

                if (vsync && frameSleepMs > 0) {
                    val elapsed = (System.nanoTime() - frameStart) / 1_000_000
                    val sleepTime = frameSleepMs - elapsed
                    if (sleepTime > 0) {
                        try { Thread.sleep(sleepTime) } catch (_: InterruptedException) { break }
                    }
                } else {
                    try { Thread.sleep(1) } catch (_: InterruptedException) { break }
                }
            }
        }, "doom-render").apply { start() }
    }

    private fun drawLoadingScreen(canvas: Canvas, frame: Long) {
        canvas.drawColor(0xFF1a0000.toInt())

        val w = canvas.width.toFloat()
        val h = canvas.height.toFloat()

        // Pulsing red vignette
        val pulseAlpha = (80 + 40 * Math.sin(frame * 0.05)).toInt()
        val vignettePaint = Paint().apply {
            shader = android.graphics.RadialGradient(
                w / 2f, h / 2f, w * 0.7f,
                intArrayOf(0x00000000.toInt(), Color.argb(pulseAlpha, 139, 0, 0)),
                floatArrayOf(0.3f, 1f),
                android.graphics.Shader.TileMode.CLAMP
            )
        }
        canvas.drawRect(0f, 0f, w, h, vignettePaint)

        // Doomguy face — bobbing animation
        val face = doomguyBitmap
        if (face != null) {
            val faceSize = (h * 0.35f).coerceAtMost(w * 0.25f)
            val bob = (Math.sin(frame * 0.08) * 6f).toFloat()
            val faceCx = w / 2f
            val faceCy = h * 0.38f + bob
            val faceRect = RectF(
                faceCx - faceSize / 2f, faceCy - faceSize / 2f,
                faceCx + faceSize / 2f, faceCy + faceSize / 2f
            )
            // Red glow behind face
            val glowPaint = Paint().apply {
                shader = android.graphics.RadialGradient(
                    faceCx, faceCy, faceSize * 0.7f,
                    intArrayOf(0x66c41e1e.toInt(), 0x00000000.toInt()),
                    null,
                    android.graphics.Shader.TileMode.CLAMP
                )
            }
            canvas.drawCircle(faceCx, faceCy, faceSize * 0.7f, glowPaint)
            canvas.drawBitmap(face, Rect(0, 0, face.width, face.height), faceRect, paint)
        }

        // Title: "CAN IT RUN DOOM?"
        val titlePaint = Paint().apply {
            color = 0xFFc41e1e.toInt()
            textSize = h * 0.07f
            textAlign = Paint.Align.CENTER
            isAntiAlias = true
            isFakeBoldText = true
        }
        canvas.drawText("CAN IT RUN DOOM?", w / 2f, h * 0.12f, titlePaint)

        // Subtitle: "BAKING DOOM ON THIS RESUME..."
        val subtitlePaint = Paint().apply {
            color = 0xFFFF6600.toLong().toInt()
            textSize = h * 0.045f
            textAlign = Paint.Align.CENTER
            isAntiAlias = true
        }
        canvas.drawText("BAKING DOOM ON THIS RESUME...", w / 2f, h * 0.20f, subtitlePaint)

        // Native engine badge
        val badgePaint = Paint().apply {
            color = 0xFF9544FF.toLong().toInt()
            textSize = h * 0.035f
            textAlign = Paint.Align.CENTER
            isAntiAlias = true
        }
        canvas.drawText("RUNNING NATIVELY ON KOTLIN • FULL PORT • NO EMULATION", w / 2f, h * 0.62f, badgePaint)

        // Animated loading dots
        val dots = ".".repeat(((frame / 15) % 4).toInt())
        val loadPaint = Paint().apply {
            color = 0xFF00FF41.toInt()
            textSize = h * 0.05f
            textAlign = Paint.Align.CENTER
            isAntiAlias = true
        }
        canvas.drawText("INITIALIZING ENGINE$dots", w / 2f, h * 0.72f, loadPaint)

        // Flickering bottom quote
        val quoteAlpha = if (frame % 60 < 50) 180 else 100
        val quotePaint = Paint().apply {
            color = Color.argb(quoteAlpha, 150, 150, 150)
            textSize = h * 0.035f
            textAlign = Paint.Align.CENTER
            isAntiAlias = true
        }
        canvas.drawText("\"RIP AND TEAR, UNTIL IT IS DONE\"", w / 2f, h * 0.90f, quotePaint)
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {}

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        rendering = false
        renderThread?.interrupt()
        renderThread?.join(1000)
        renderThread = null
    }
}

/**
 * Touch control overlay for DOOM — D-pad, fire, use, strafe.
 * Sends DOOM key codes (matching java.awt.event.KeyEvent VK_ values).
 */
class DoomTouchControls(
    context: Context,
    swipeSensitivity: Float = 8f,
    private val onKey: (keyCode: Int, pressed: Boolean) -> Unit
) : View(context) {

    private val buttonPaint = Paint().apply {
        color = 0x66000000.toInt()
        isAntiAlias = true
    }

    private val pressedPaint = Paint().apply {
        color = 0x99c41e1e.toLong().toInt()
        isAntiAlias = true
    }

    private val borderPaint = Paint().apply {
        color = 0xAAc41e1e.toLong().toInt()
        style = Paint.Style.STROKE
        strokeWidth = 2f
        isAntiAlias = true
    }

    private val textPaint = Paint().apply {
        color = 0xBBFFFFFF.toLong().toInt()
        textSize = 22f
        textAlign = Paint.Align.CENTER
        isAntiAlias = true
    }

    // DOOM-themed close button paints
    private val closeFillPaint = Paint().apply {
        color = 0xDD8B0000.toLong().toInt() // dark blood red
        isAntiAlias = true
    }

    private val closePressedPaint = Paint().apply {
        color = 0xFFFF2200.toLong().toInt() // hellfire orange-red when pressed
        isAntiAlias = true
    }

    private val closeBorderPaint = Paint().apply {
        color = 0xFFFF4444.toLong().toInt() // bright red border
        style = Paint.Style.STROKE
        strokeWidth = 3f
        isAntiAlias = true
    }

    private val closeXPaint = Paint().apply {
        color = 0xFFFFDD00.toLong().toInt() // demon-eye yellow
        strokeWidth = 4f
        strokeCap = Paint.Cap.ROUND
        isAntiAlias = true
        style = Paint.Style.STROKE
    }

    data class TouchButton(
        val label: String,
        val keyCode: Int,
        val keyCode2: Int = 0, // optional second key to send simultaneously
        var cx: Float = 0f,
        var cy: Float = 0f,
        var radius: Float = 50f,
        var pressed: Boolean = false
    )

    private val buttons = mutableListOf<TouchButton>()

    // Swipe turning state
    private val pointerStartX = HashMap<Int, Float>()
    private var swipeTurning = 0 // -1 = left, 0 = none, 1 = right
    private val swipeThreshold = swipeSensitivity

    // DOOM key codes (matching java.awt.event.KeyEvent VK_ constants)
    companion object {
        const val KEY_W = 87       // VK_W → SC_W matches engine's key_up (forward)
        const val KEY_S = 83       // VK_S → SC_S matches engine's key_down (backward)
        const val KEY_LEFT = 37    // VK_LEFT → SC_LEFT (turn left)
        const val KEY_RIGHT = 39   // VK_RIGHT → SC_RIGHT (turn right)
        const val KEY_UP = 38      // VK_UP → SC_UP (menu navigation)
        const val KEY_DOWN = 40    // VK_DOWN → SC_DOWN (menu navigation)
        const val KEY_FIRE = 17    // VK_CONTROL
        const val KEY_USE = 32     // VK_SPACE
        const val KEY_RUN = 16     // VK_SHIFT
        const val KEY_STRAFE_L = 44 // VK_COMMA (strafe left)
        const val KEY_STRAFE_R = 46 // VK_PERIOD (strafe right)
        const val KEY_ESCAPE = 27
        const val KEY_ENTER = 10
        const val KEY_TAB = 9      // Automap
        const val KEY_CLOSE = -1   // Special: close game, not a DOOM key
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)

        val r = 52f
        val pad = 24f

        buttons.clear()

        // D-pad (left side) — W/S move forward/back + send arrow keys for menus
        val dCx = pad + r * 3
        val dCy = h - pad - r * 3

        buttons.add(TouchButton("W", KEY_W, KEY_UP, dCx, dCy - r * 2.1f, r))
        buttons.add(TouchButton("S", KEY_S, KEY_DOWN, dCx, dCy + r * 2.1f, r))
        buttons.add(TouchButton("◄", KEY_LEFT, 0, dCx - r * 2.1f, dCy, r))
        buttons.add(TouchButton("►", KEY_RIGHT, 0, dCx + r * 2.1f, dCy, r))

        // Strafe buttons (flanking D-pad)
        buttons.add(TouchButton("SL", KEY_STRAFE_L, 0, dCx - r * 4.2f, dCy, r * 0.7f))
        buttons.add(TouchButton("SR", KEY_STRAFE_R, 0, dCx + r * 4.2f, dCy, r * 0.7f))

        // Action buttons (right side)
        val aCx = w - pad - r * 3
        val aCy = h - pad - r * 3

        buttons.add(TouchButton("FIRE", KEY_FIRE, 0, aCx + r, aCy - r * 1.5f, r * 1.3f))
        buttons.add(TouchButton("USE", KEY_USE, 0, aCx - r * 1.5f, aCy, r))
        buttons.add(TouchButton("RUN", KEY_RUN, 0, aCx + r, aCy + r * 2f, r * 0.8f))

        // Top buttons
        buttons.add(TouchButton("ESC", KEY_ESCAPE, 0, w - pad - r, pad + r, r * 0.65f))
        buttons.add(TouchButton("MAP", KEY_TAB, 0, w - pad - r * 3, pad + r, r * 0.65f))
        buttons.add(TouchButton("ENT", KEY_ENTER, 0, w - pad - r * 5, pad + r, r * 0.65f))

        // Close button (top-left)
        buttons.add(TouchButton("✕", KEY_CLOSE, 0, pad + r, pad + r, r * 0.65f))
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        for (btn in buttons) {
            if (btn.keyCode == KEY_CLOSE) {
                // DOOM-themed close button: blood red with yellow X
                canvas.drawCircle(btn.cx, btn.cy, btn.radius, if (btn.pressed) closePressedPaint else closeFillPaint)
                canvas.drawCircle(btn.cx, btn.cy, btn.radius, closeBorderPaint)
                // Draw X with thick strokes
                val xSize = btn.radius * 0.45f
                canvas.drawLine(btn.cx - xSize, btn.cy - xSize, btn.cx + xSize, btn.cy + xSize, closeXPaint)
                canvas.drawLine(btn.cx + xSize, btn.cy - xSize, btn.cx - xSize, btn.cy + xSize, closeXPaint)
            } else {
                canvas.drawCircle(btn.cx, btn.cy, btn.radius, if (btn.pressed) pressedPaint else buttonPaint)
                canvas.drawCircle(btn.cx, btn.cy, btn.radius, borderPaint)
                canvas.drawText(btn.label, btn.cx, btn.cy + 8f, textPaint)
            }
        }
    }

    private fun isOverButton(x: Float, y: Float): Boolean {
        for (btn in buttons) {
            val dx = x - btn.cx
            val dy = y - btn.cy
            if (dx * dx + dy * dy <= btn.radius * btn.radius * 1.6f) return true
        }
        return false
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_POINTER_DOWN -> {
                val idx = event.actionIndex
                val pid = event.getPointerId(idx)
                if (!isOverButton(event.getX(idx), event.getY(idx))) {
                    pointerStartX[pid] = event.getX(idx)
                }
            }

            MotionEvent.ACTION_POINTER_UP -> {
                val idx = event.actionIndex
                val pid = event.getPointerId(idx)
                pointerStartX.remove(pid)
            }

            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                pointerStartX.clear()
                if (swipeTurning != 0) {
                    if (swipeTurning == -1) onKey(KEY_LEFT, false)
                    else onKey(KEY_RIGHT, false)
                    swipeTurning = 0
                }
            }
        }

        // Handle swipe turning from any non-button pointer
        if (event.actionMasked == MotionEvent.ACTION_MOVE) {
            var newTurn = 0
            for (i in 0 until event.pointerCount) {
                val pid = event.getPointerId(i)
                val startX = pointerStartX[pid] ?: continue
                val deltaX = event.getX(i) - startX
                if (deltaX > swipeThreshold) newTurn = 1
                else if (deltaX < -swipeThreshold) newTurn = -1
                // Update start position for continuous turning
                if (Math.abs(deltaX) > swipeThreshold) {
                    pointerStartX[pid] = event.getX(i)
                }
            }
            if (newTurn != swipeTurning) {
                if (swipeTurning == -1) onKey(KEY_LEFT, false)
                else if (swipeTurning == 1) onKey(KEY_RIGHT, false)
                if (newTurn == -1) onKey(KEY_LEFT, true)
                else if (newTurn == 1) onKey(KEY_RIGHT, true)
                swipeTurning = newTurn
            }
        }

        // Handle button presses
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_POINTER_DOWN,
            MotionEvent.ACTION_POINTER_UP, MotionEvent.ACTION_MOVE -> {
                val liftedIdx = if (event.actionMasked == MotionEvent.ACTION_POINTER_UP)
                    event.actionIndex else -1

                for (btn in buttons) {
                    var touching = false
                    for (i in 0 until event.pointerCount) {
                        if (i == liftedIdx) continue
                        val dx = event.getX(i) - btn.cx
                        val dy = event.getY(i) - btn.cy
                        if (dx * dx + dy * dy <= btn.radius * btn.radius * 1.6f) {
                            touching = true
                            break
                        }
                    }
                    if (touching && !btn.pressed) {
                        btn.pressed = true
                        onKey(btn.keyCode, true)
                        if (btn.keyCode2 != 0) onKey(btn.keyCode2, true)
                    } else if (!touching && btn.pressed) {
                        btn.pressed = false
                        onKey(btn.keyCode, false)
                        if (btn.keyCode2 != 0) onKey(btn.keyCode2, false)
                    }
                }
                invalidate()
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                for (btn in buttons) {
                    if (btn.pressed) {
                        btn.pressed = false
                        onKey(btn.keyCode, false)
                        if (btn.keyCode2 != 0) onKey(btn.keyCode2, false)
                    }
                }
                invalidate()
            }
        }
        return true
    }
}
