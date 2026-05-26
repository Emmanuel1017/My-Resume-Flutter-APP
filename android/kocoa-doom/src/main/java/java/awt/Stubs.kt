@file:Suppress("UNUSED_PARAMETER", "unused")
package java.awt

import java.awt.event.*
import java.awt.image.*
import java.io.File

// ============ Basic Types ============

open class Dimension(var width: Int = 0, var height: Int = 0)

open class Point(var x: Int = 0, var y: Int = 0)

open class Rectangle(
    var x: Int = 0,
    var y: Int = 0,
    var width: Int = 0,
    var height: Int = 0
) {
    constructor(w: Int, h: Int) : this(0, 0, w, h)
    fun contains(px: Int, py: Int): Boolean = px in x until (x + width) && py in y until (y + height)
    fun contains(p: Point): Boolean = contains(p.x, p.y)
    fun setBounds(x: Int, y: Int, width: Int, height: Int) { this.x = x; this.y = y; this.width = width; this.height = height }
    fun setBounds(r: Rectangle) { x = r.x; y = r.y; width = r.width; height = r.height }
    fun getWidth(): Double = width.toDouble()
    fun getHeight(): Double = height.toDouble()
    fun getX(): Double = x.toDouble()
    fun getY(): Double = y.toDouble()
}

open class Insets(
    var top: Int = 0,
    var left: Int = 0,
    var bottom: Int = 0,
    var right: Int = 0
)

// ============ Color ============

open class Color(val rgb: Int) {
    constructor(r: Int, g: Int, b: Int) : this((0xFF shl 24) or ((r and 0xFF) shl 16) or ((g and 0xFF) shl 8) or (b and 0xFF))
    constructor(r: Int, g: Int, b: Int, a: Int) : this(((a and 0xFF) shl 24) or ((r and 0xFF) shl 16) or ((g and 0xFF) shl 8) or (b and 0xFF))
    constructor(r: Float, g: Float, b: Float) : this((r * 255).toInt(), (g * 255).toInt(), (b * 255).toInt())

    open fun getRed(): Int = (rgb shr 16) and 0xFF
    open fun getGreen(): Int = (rgb shr 8) and 0xFF
    open fun getBlue(): Int = rgb and 0xFF
    open fun getAlpha(): Int = (rgb shr 24) and 0xFF
    open fun getRGB(): Int = rgb

    companion object {
        @JvmField val BLACK = Color(0, 0, 0)
        @JvmField val WHITE = Color(255, 255, 255)
        @JvmField val RED = Color(255, 0, 0)
        @JvmField val GREEN = Color(0, 255, 0)
        @JvmField val BLUE = Color(0, 0, 255)
        @JvmField val YELLOW = Color(255, 255, 0)
        @JvmField val CYAN = Color(0, 255, 255)
        @JvmField val MAGENTA = Color(255, 0, 255)
        @JvmField val ORANGE = Color(255, 200, 0)
        @JvmField val PINK = Color(255, 175, 175)
        @JvmField val GRAY = Color(128, 128, 128)
        @JvmField val DARK_GRAY = Color(64, 64, 64)
        @JvmField val LIGHT_GRAY = Color(192, 192, 192)
        @JvmField val black = BLACK
        @JvmField val white = WHITE
        @JvmField val red = RED
        @JvmField val green = GREEN
        @JvmField val blue = BLUE
        @JvmField val yellow = YELLOW
        @JvmField val cyan = CYAN
        @JvmField val magenta = MAGENTA
        @JvmField val orange = ORANGE
        @JvmField val pink = PINK
        @JvmField val gray = GRAY
    }
}

// ============ Graphics ============

abstract class Graphics {
    open fun dispose() {}
    open fun drawImage(img: Image?, x: Int, y: Int, observer: java.awt.image.ImageObserver?): Boolean = true
    open fun drawImage(img: Image?, x: Int, y: Int, width: Int, height: Int, observer: java.awt.image.ImageObserver?): Boolean = true
    open fun drawImage(img: Image?, x: Int, y: Int, bgcolor: Color?, observer: java.awt.image.ImageObserver?): Boolean = true
    open fun drawImage(img: Image?, dx1: Int, dy1: Int, dx2: Int, dy2: Int, sx1: Int, sy1: Int, sx2: Int, sy2: Int, observer: java.awt.image.ImageObserver?): Boolean = true
    open fun setColor(c: Color?) {}
    open fun getColor(): Color = Color.BLACK
    open fun fillRect(x: Int, y: Int, width: Int, height: Int) {}
    open fun drawRect(x: Int, y: Int, width: Int, height: Int) {}
    open fun drawString(str: String?, x: Int, y: Int) {}
    open fun drawLine(x1: Int, y1: Int, x2: Int, y2: Int) {}
    open fun setFont(font: Font?) {}
    open fun getFont(): Font = Font("Default", Font.PLAIN, 12)
    open fun getFontMetrics(): FontMetrics = FontMetrics(getFont())
    open fun getFontMetrics(f: Font?): FontMetrics = FontMetrics(f ?: getFont())
    open fun getClipBounds(): Rectangle = Rectangle(0, 0, 9999, 9999)
    open fun clipRect(x: Int, y: Int, width: Int, height: Int) {}
    open fun setClip(x: Int, y: Int, width: Int, height: Int) {}
    open fun translate(x: Int, y: Int) {}
    open fun create(): Graphics = this
}

open class Graphics2D : Graphics() {
    open fun drawImage(img: Image?, op: Any?, x: Int, y: Int) {}
    open fun scale(sx: Double, sy: Double) {}
    open fun rotate(theta: Double) {}
    open fun setRenderingHint(key: Any?, value: Any?) {}
    open fun setComposite(comp: Any?) {}
    open fun setStroke(s: Any?) {}
    open fun setPaint(paint: Any?) {}
    open fun getRenderingHints(): Any? = null
}

// ============ Font / FontMetrics ============

open class Font(private val _name: String? = "Default", private val _style: Int = PLAIN, private val _size: Int = 12) {
    companion object {
        const val PLAIN = 0
        const val BOLD = 1
        const val ITALIC = 2
    }
    open fun getSize(): Int = _size
    open fun getStyle(): Int = _style
    open fun getName(): String = _name ?: "Default"
}

open class FontMetrics(val font: Font) {
    open fun getHeight(): Int = font.getSize() + 4
    open fun getAscent(): Int = font.getSize()
    open fun getDescent(): Int = 4
    open fun getLeading(): Int = 0
    open fun stringWidth(str: String?): Int = (str?.length ?: 0) * (font.getSize() / 2)
    open fun charWidth(ch: Char): Int = font.getSize() / 2
}

// ============ Cursor ============

open class Cursor(val type: Int = DEFAULT_CURSOR) {
    companion object {
        const val DEFAULT_CURSOR = 0
        const val CROSSHAIR_CURSOR = 1
        const val HAND_CURSOR = 12
        const val MOVE_CURSOR = 13
        const val TEXT_CURSOR = 2
        const val WAIT_CURSOR = 3
        const val CUSTOM_CURSOR = -1

        @JvmStatic
        fun getPredefinedCursor(type: Int): Cursor = Cursor(type)
    }
}

// ============ Toolkit ============

open class Toolkit {
    open val screenSize: Dimension = Dimension(1920, 1080)
    open fun createImage(width: Int, height: Int): Image = BufferedImage(width, height, BufferedImage.TYPE_INT_ARGB)
    open fun sync() {}
    open fun createCustomCursor(cursor: Image?, hotSpot: Point?, name: String?): Cursor = Cursor(Cursor.CUSTOM_CURSOR)
    open fun getBestCursorSize(preferredWidth: Int, preferredHeight: Int): Dimension = Dimension(32, 32)
    open fun addAWTEventListener(listener: AWTEventListener?, eventMask: Long) {}
    open fun removeAWTEventListener(listener: AWTEventListener?) {}

    companion object {
        @JvmStatic
        fun getDefaultToolkit(): Toolkit = Toolkit()
    }
}

// ============ Button ============

open class Button : Component {
    @JvmField var label: String? = null

    constructor() : super()
    constructor(label: String?) : super() { this.label = label }

    open fun getLabel(): String? = label
    open fun setLabel(label: String?) { this.label = label }
    open fun addActionListener(l: java.awt.event.ActionListener?) {}
    open fun removeActionListener(l: java.awt.event.ActionListener?) {}
}

// ============ Image (base class) ============

open class Image {
    @JvmField var accelerationPriority: Float = 0.5f

    open fun getWidth(observer: java.awt.image.ImageObserver?): Int = 0
    open fun getHeight(observer: java.awt.image.ImageObserver?): Int = 0
    open fun getGraphics(): Graphics = Graphics2D()
    open fun flush() {}
    open fun getAccelerationPriority(): Float = accelerationPriority
    open fun setAccelerationPriority(priority: Float) { accelerationPriority = priority }

    companion object {
        const val SCALE_DEFAULT = 1
        const val SCALE_FAST = 2
        const val SCALE_SMOOTH = 4
        const val SCALE_REPLICATE = 8
        const val SCALE_AREA_AVERAGING = 16
    }
}

// ============ Transparency ============

interface Transparency {
    fun getTransparency(): Int

    companion object {
        const val OPAQUE = 1
        const val BITMASK = 2
        const val TRANSLUCENT = 3
    }
}

// ============ DisplayMode ============

open class DisplayMode(
    val width: Int,
    val height: Int,
    val bitDepth: Int,
    val refreshRate: Int
) {
    companion object {
        const val BIT_DEPTH_MULTI = -1
        const val REFRESH_RATE_UNKNOWN = 0
    }
}

// ============ GraphicsDevice / GraphicsEnvironment / GraphicsConfiguration ============

open class GraphicsConfiguration {
    open fun createCompatibleImage(width: Int, height: Int): BufferedImage =
        BufferedImage(width, height, BufferedImage.TYPE_INT_ARGB)

    open fun createCompatibleImage(width: Int, height: Int, transparency: Int): BufferedImage =
        BufferedImage(width, height, BufferedImage.TYPE_INT_ARGB)

    open fun createCompatibleVolatileImage(width: Int, height: Int): VolatileImage =
        VolatileImage(width, height)

    open fun createCompatibleVolatileImage(width: Int, height: Int, transparency: Int): VolatileImage =
        VolatileImage(width, height)

    open fun getColorModel(): java.awt.image.ColorModel = java.awt.image.ColorModel(32)
    open fun getBounds(): Rectangle = Rectangle(0, 0, 1920, 1080)
}

open class GraphicsDevice {
    @JvmField var displayMode: DisplayMode = DisplayMode(1920, 1080, 32, 60)
    @JvmField var fullScreenWindow: Window? = null
    @JvmField var isFullScreenSupported: Boolean = false
    @JvmField var isDisplayChangeSupported: Boolean = false

    open val displayModes: Array<DisplayMode> get() = arrayOf(displayMode)

    open fun getDefaultConfiguration(): GraphicsConfiguration = GraphicsConfiguration()
    open fun setDisplayMode(dm: DisplayMode?) { if (dm != null) displayMode = dm }
    open fun setFullScreenWindow(w: Window?) { fullScreenWindow = w }
    open fun getFullScreenWindow(): Window? = fullScreenWindow
    open fun isDisplayable(): Boolean = true

    companion object {
        const val TYPE_RASTER_SCREEN = 0
    }
}

open class GraphicsEnvironment {
    open val defaultScreenDevice: GraphicsDevice get() = GraphicsDevice()
    open fun getScreenDevices(): Array<GraphicsDevice> = arrayOf(GraphicsDevice())

    companion object {
        @JvmStatic
        fun getLocalGraphicsEnvironment(): GraphicsEnvironment = GraphicsEnvironment()

        @JvmStatic
        fun isHeadless(): Boolean = true
    }
}

// ============ AWTEvent ============

open class AWTEvent(@JvmField var source: Any? = null, val id: Int = 0) {
    open fun getID(): Int = id
    open fun getSource(): Any? = source
}

// ============ Component / Container / Window / Frame / Canvas ============

open class Component : java.awt.image.ImageObserver {
    override fun imageUpdate(img: Image?, infoflags: Int, x: Int, y: Int, width: Int, height: Int): Boolean = true
    @JvmField var isVisible: Boolean = false
    @JvmField var isEnabled: Boolean = true
    @JvmField var isShowing: Boolean = false
    @JvmField var isDisplayable: Boolean = false
    @JvmField var focusTraversalKeysEnabled: Boolean = true
    @JvmField var inputContext: InputContext = InputContext()
    @JvmField var width: Int = 0
    @JvmField var height: Int = 0
    @JvmField var preferredSize: Dimension? = Dimension(0, 0)
    @JvmField var cursor: Cursor = Cursor()
    @JvmField var background: Color = Color.BLACK
    @JvmField var foreground: Color = Color.WHITE
    @JvmField var graphics: Graphics? = Graphics2D()
    @JvmField var toolkit: Toolkit = Toolkit.getDefaultToolkit()
    @JvmField var locationOnScreen: Point = Point(0, 0)

    open fun setSize(width: Int, height: Int) { this.width = width; this.height = height }
    open fun setSize(d: Dimension?) { if (d != null) { width = d.width; height = d.height } }
    open fun getSize(): Dimension = Dimension(width, height)
    open fun getWidth(): Int = width
    open fun getHeight(): Int = height
    open fun setPreferredSize(d: Dimension?) { preferredSize = d }
    open fun getPreferredSize(): Dimension = preferredSize ?: Dimension(0, 0)
    open fun setMinimumSize(d: Dimension?) {}
    open fun getMinimumSize(): Dimension = Dimension(0, 0)
    open fun setLocation(x: Int, y: Int) {}
    open fun getLocation(): Point = Point(0, 0)
    open fun getLocationOnScreen(): Point = locationOnScreen
    open fun setBounds(x: Int, y: Int, width: Int, height: Int) { this.width = width; this.height = height }
    open fun getBounds(): Rectangle = Rectangle(0, 0, width, height)
    open fun setVisible(b: Boolean) { isVisible = b }
    open fun setEnabled(b: Boolean) { isEnabled = b }
    open fun repaint() {}
    open fun revalidate() {}
    open fun invalidate() {}
    open fun validate() {}
    open fun paint(g: Graphics?) {}
    open fun update(g: Graphics?) {}
    open fun getGraphics(): Graphics? = graphics
    open fun createImage(width: Int, height: Int): Image = BufferedImage(width, height, BufferedImage.TYPE_INT_ARGB)
    open fun getGraphicsConfiguration(): GraphicsConfiguration = GraphicsConfiguration()
    open fun addKeyListener(l: Any?) {}
    open fun removeKeyListener(l: Any?) {}
    open fun addMouseListener(l: Any?) {}
    open fun removeMouseListener(l: Any?) {}
    open fun addMouseMotionListener(l: Any?) {}
    open fun removeMouseMotionListener(l: Any?) {}
    open fun addComponentListener(l: Any?) {}
    open fun removeComponentListener(l: Any?) {}
    open fun setCursor(c: Cursor?) { if (c != null) cursor = c }
    open fun getCursor(): Cursor = cursor
    open fun requestFocus() {}
    open fun requestFocusInWindow(): Boolean = true
    open fun hasFocus(): Boolean = false
    open fun setFocusable(b: Boolean) {}
    open fun isFocusable(): Boolean = true
    open fun setBackground(c: Color?) { if (c != null) background = c }
    open fun getBackground(): Color = background
    open fun setForeground(c: Color?) { if (c != null) foreground = c }
    open fun getForeground(): Color = foreground
    open fun setFont(f: Font?) {}
    open fun getFont(): Font = Font()
    open fun getFontMetrics(f: Font?): FontMetrics = FontMetrics(f ?: Font())
    open fun getToolkit(): Toolkit = toolkit
    open fun getInsets(): Insets = Insets()
    open fun setIgnoreRepaint(b: Boolean) {}
    open fun createBufferStrategy(numBuffers: Int) {}
    open fun getBufferStrategy(): BufferStrategy? = null
    open fun addNotify() {}
    open fun removeNotify() {}
    open fun getParent(): Container? = null
    open fun enableInputMethods(enable: Boolean) {}
    open fun addMouseWheelListener(l: Any?) {}
    open fun removeMouseWheelListener(l: Any?) {}
    open fun addFocusListener(l: Any?) {}
    open fun removeFocusListener(l: Any?) {}
}

open class Container : Component() {
    @JvmField var layout: Any? = null

    @JvmField @Suppress("LeakingThis")
    var contentPane: Container = this

    open fun add(comp: Component?): Component? = comp
    open fun add(comp: Component?, constraints: Any?): Unit {}
    open fun add(name: String?, comp: Component?): Component? = comp
    open fun remove(comp: Component?) {}
    open fun removeAll() {}
    open fun setLayout(mgr: Any?) { layout = mgr }
    open fun getLayout(): Any? = layout
    open fun getComponents(): Array<Component> = emptyArray()
    open fun getComponentCount(): Int = 0
}

open class Window(owner: Window? = null) : Container() {
    constructor(owner: Frame?) : this(owner as? Window)

    open fun pack() {}
    open fun dispose() {}
    open fun toFront() {}
    open fun setLocationRelativeTo(c: Component?) {}
    open fun addWindowListener(l: Any?) {}
    open fun removeWindowListener(l: Any?) {}
    open fun addWindowFocusListener(l: Any?) {}
    open fun removeWindowFocusListener(l: Any?) {}
    open fun isActive(): Boolean = false
    open fun addActionListener(l: Any?) {}
    open fun removeActionListener(l: Any?) {}
    open fun isShowing(): Boolean = isShowing
    open fun isDisplayable(): Boolean = isDisplayable
}

open class Frame(title: String? = "") : Window() {
    @JvmField var title: String? = title
    @JvmField var isResizable: Boolean = true
    @JvmField var isUndecorated: Boolean = false
    @JvmField var iconImage: Image? = null

    open fun setTitle(t: String?) { title = t }
    open fun getTitle(): String? = title
    open fun setResizable(b: Boolean) { isResizable = b }
    open fun setUndecorated(b: Boolean) { isUndecorated = b }
    open fun setIconImage(image: Image?) { iconImage = image }
    open fun setMenuBar(mb: Any?) {}
    open fun getMenuBar(): Any? = null
    open fun setExtendedState(state: Int) {}
    open fun getExtendedState(): Int = NORMAL

    companion object {
        const val NORMAL = 0
        const val ICONIFIED = 1
        const val MAXIMIZED_HORIZ = 2
        const val MAXIMIZED_VERT = 4
        const val MAXIMIZED_BOTH = 6
    }
}

open class Dialog(owner: Frame? = null, title: String? = "", modal: Boolean = false) : Window() {
    open fun setTitle(t: String?) {}
    open fun getTitle(): String? = ""
    open fun setModal(b: Boolean) {}
    open fun isModal(): Boolean = false
}

open class Canvas : Component {
    constructor() : super()
    constructor(config: GraphicsConfiguration?) : super()

    override fun createBufferStrategy(numBuffers: Int) {}
    override fun getBufferStrategy(): BufferStrategy? = null
}

open class Panel : Container()

// ============ BufferStrategy ============

open class BufferStrategy {
    open fun getDrawGraphics(): Graphics = Graphics2D()
    open fun contentsLost(): Boolean = false
    open fun contentsRestored(): Boolean = false
    open fun show() {}
    open fun dispose() {}
}

// ============ Robot ============

open class Robot {
    constructor()
    constructor(screen: GraphicsDevice?)

    open fun mouseMove(x: Int, y: Int) {}
    open fun mousePress(buttons: Int) {}
    open fun mouseRelease(buttons: Int) {}
    open fun keyPress(keycode: Int) {}
    open fun keyRelease(keycode: Int) {}
    open fun createScreenCapture(screenRect: Rectangle?): BufferedImage = BufferedImage(1, 1, BufferedImage.TYPE_INT_ARGB)
    open fun delay(ms: Int) {}
}

// ============ RenderingHints ============

open class RenderingHints(initialCapacity: Int = 16) : MutableMap<Any, Any> by HashMap() {
    constructor(key: Key?, value: Any?) : this() {
        if (key != null && value != null) put(key, value)
    }

    open class Key(val intKey: Int) {
        open fun isCompatibleValue(v: Any?): Boolean = true
    }

    companion object {
        @JvmField val KEY_ANTIALIASING = Key(1)
        @JvmField val VALUE_ANTIALIAS_ON = Object()
        @JvmField val VALUE_ANTIALIAS_OFF = Object()
        @JvmField val KEY_RENDERING = Key(2)
        @JvmField val VALUE_RENDER_QUALITY = Object()
        @JvmField val VALUE_RENDER_SPEED = Object()
        @JvmField val KEY_INTERPOLATION = Key(3)
        @JvmField val VALUE_INTERPOLATION_BILINEAR = Object()
        @JvmField val VALUE_INTERPOLATION_BICUBIC = Object()
        @JvmField val VALUE_INTERPOLATION_NEAREST_NEIGHBOR = Object()
        @JvmField val KEY_TEXT_ANTIALIASING = Key(4)
        @JvmField val VALUE_TEXT_ANTIALIAS_ON = Object()
        @JvmField val KEY_ALPHA_INTERPOLATION = Key(5)
        @JvmField val VALUE_ALPHA_INTERPOLATION_SPEED = Object()
        @JvmField val VALUE_ALPHA_INTERPOLATION_QUALITY = Object()
        @JvmField val VALUE_ALPHA_INTERPOLATION_DEFAULT = Object()
        @JvmField val KEY_COLOR_RENDERING = Key(6)
        @JvmField val VALUE_COLOR_RENDER_SPEED = Object()
        @JvmField val VALUE_COLOR_RENDER_QUALITY = Object()
        @JvmField val KEY_DITHERING = Key(7)
        @JvmField val VALUE_DITHER_ENABLE = Object()
        @JvmField val VALUE_DITHER_DISABLE = Object()
        @JvmField val KEY_FRACTIONALMETRICS = Key(8)
        @JvmField val VALUE_FRACTIONALMETRICS_ON = Object()
        @JvmField val VALUE_FRACTIONALMETRICS_OFF = Object()
        @JvmField val KEY_STROKE_CONTROL = Key(9)
        @JvmField val VALUE_STROKE_NORMALIZE = Object()
        @JvmField val VALUE_STROKE_PURE = Object()
    }
}

// ============ Event / EventQueue / AWTEventListener ============

fun interface AWTEventListener {
    fun eventDispatched(event: AWTEvent)
}

open class EventQueue {
    open fun postEvent(event: AWTEvent?) {}

    companion object {
        @JvmStatic
        fun invokeLater(runnable: Runnable?) { runnable?.run() }

        @JvmStatic
        fun invokeAndWait(runnable: Runnable?) { runnable?.run() }

        @JvmStatic
        fun isDispatchThread(): Boolean = true
    }
}

// ============ LayoutManager ============

interface LayoutManager {
    fun addLayoutComponent(name: String?, comp: Component?) {}
    fun removeLayoutComponent(comp: Component?) {}
    fun preferredLayoutSize(parent: Container?): Dimension = Dimension()
    fun minimumLayoutSize(parent: Container?): Dimension = Dimension()
    fun layoutContainer(parent: Container?) {}
}

open class BorderLayout(hgap: Int = 0, vgap: Int = 0) : LayoutManager {
    companion object {
        const val NORTH = "North"
        const val SOUTH = "South"
        const val EAST = "East"
        const val WEST = "West"
        const val CENTER = "Center"
    }
}

open class FlowLayout(align: Int = CENTER, hgap: Int = 5, vgap: Int = 5) : LayoutManager {
    companion object {
        const val LEFT = 0
        const val CENTER = 1
        const val RIGHT = 2
    }
}

open class GridLayout(rows: Int = 1, cols: Int = 0, hgap: Int = 0, vgap: Int = 0) : LayoutManager

// ============ Menu ============

open class MenuBar
open class Menu(label: String? = "")
open class MenuItem(label: String? = "") {
    open fun addActionListener(l: Any?) {}
}
open class CheckboxMenuItem(label: String? = "", state: Boolean = false) : MenuItem(label)

// ============ Event dispatching interfaces ============

interface ItemSelectable {
    fun getSelectedObjects(): Array<Any>?
}

// ============ AlphaComposite ============

open class AlphaComposite private constructor(val rule: Int, val alpha: Float = 1.0f) {
    companion object {
        const val CLEAR = 1
        const val SRC = 2
        const val DST = 9
        const val SRC_OVER = 3
        const val DST_OVER = 4
        const val SRC_IN = 5
        const val DST_IN = 6
        const val SRC_OUT = 7
        const val DST_OUT = 8

        @JvmField val Clear = AlphaComposite(CLEAR)
        @JvmField val Src = AlphaComposite(SRC)
        @JvmField val SrcOver = AlphaComposite(SRC_OVER)

        @JvmStatic
        fun getInstance(rule: Int): AlphaComposite = AlphaComposite(rule)

        @JvmStatic
        fun getInstance(rule: Int, alpha: Float): AlphaComposite = AlphaComposite(rule, alpha)
    }
}

// ============ BasicStroke ============

open class BasicStroke(
    val width: Float = 1.0f,
    val cap: Int = CAP_SQUARE,
    val join: Int = JOIN_MITER,
    val miterLimit: Float = 10.0f
) {
    constructor(width: Float) : this(width, CAP_SQUARE, JOIN_MITER)

    companion object {
        const val CAP_BUTT = 0
        const val CAP_ROUND = 1
        const val CAP_SQUARE = 2
        const val JOIN_MITER = 0
        const val JOIN_ROUND = 1
        const val JOIN_BEVEL = 2
    }
}

// ============ Misc ============

open class MediaTracker(comp: Component?) {
    open fun addImage(image: Image?, id: Int) {}
    open fun waitForAll() {}
    open fun waitForID(id: Int) {}
    open fun isErrorAny(): Boolean = false
}

open class SystemColor : Color(0) {
    companion object {
        @JvmField val desktop = Color(0)
        @JvmField val window = Color(0xFFFFFF)
        @JvmField val windowText = Color(0)
    }
}

interface Shape
interface Paint
interface Stroke
interface Composite

// ============ InputContext ============

open class InputContext {
    open fun selectInputMethod(locale: java.util.Locale?): Boolean = true
    open fun dispose() {}
    open fun endComposition() {}
}

// ============ AWTException ============

open class AWTException(message: String? = null) : Exception(message)
