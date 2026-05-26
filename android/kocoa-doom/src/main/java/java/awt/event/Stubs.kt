@file:Suppress("UNUSED_PARAMETER", "unused")
package java.awt.event

import java.awt.AWTEvent
import java.awt.Component

// ============ Event Listeners ============

interface ActionListener {
    fun actionPerformed(e: ActionEvent)
}

interface KeyListener {
    fun keyTyped(e: KeyEvent?)
    fun keyPressed(e: KeyEvent?)
    fun keyReleased(e: KeyEvent?)
}

interface MouseListener {
    fun mouseClicked(e: MouseEvent?)
    fun mousePressed(e: MouseEvent?)
    fun mouseReleased(e: MouseEvent?)
    fun mouseEntered(e: MouseEvent?)
    fun mouseExited(e: MouseEvent?)
}

interface MouseMotionListener {
    fun mouseDragged(e: MouseEvent?)
    fun mouseMoved(e: MouseEvent?)
}

interface MouseWheelListener {
    fun mouseWheelMoved(e: MouseWheelEvent?)
}

interface ComponentListener {
    fun componentResized(e: ComponentEvent?)
    fun componentMoved(e: ComponentEvent?)
    fun componentShown(e: ComponentEvent?)
    fun componentHidden(e: ComponentEvent?)
}

interface WindowListener {
    fun windowOpened(e: WindowEvent?)
    fun windowClosing(e: WindowEvent?)
    fun windowClosed(e: WindowEvent?)
    fun windowIconified(e: WindowEvent?)
    fun windowDeiconified(e: WindowEvent?)
    fun windowActivated(e: WindowEvent?)
    fun windowDeactivated(e: WindowEvent?)
}

interface WindowFocusListener {
    fun windowGainedFocus(e: WindowEvent?)
    fun windowLostFocus(e: WindowEvent?)
}

interface FocusListener {
    fun focusGained(e: FocusEvent?)
    fun focusLost(e: FocusEvent?)
}

interface ItemListener {
    fun itemStateChanged(e: ItemEvent?)
}

interface AdjustmentListener {
    fun adjustmentValueChanged(e: AdjustmentEvent?)
}

interface InputMethodListener

// ============ Adapter classes ============

open class KeyAdapter : KeyListener {
    override fun keyTyped(e: KeyEvent?) {}
    override fun keyPressed(e: KeyEvent?) {}
    override fun keyReleased(e: KeyEvent?) {}
}

open class MouseAdapter : MouseListener, MouseMotionListener, MouseWheelListener {
    override fun mouseClicked(e: MouseEvent?) {}
    override fun mousePressed(e: MouseEvent?) {}
    override fun mouseReleased(e: MouseEvent?) {}
    override fun mouseEntered(e: MouseEvent?) {}
    override fun mouseExited(e: MouseEvent?) {}
    override fun mouseDragged(e: MouseEvent?) {}
    override fun mouseMoved(e: MouseEvent?) {}
    override fun mouseWheelMoved(e: MouseWheelEvent?) {}
}

open class ComponentAdapter : ComponentListener {
    override fun componentResized(e: ComponentEvent?) {}
    override fun componentMoved(e: ComponentEvent?) {}
    override fun componentShown(e: ComponentEvent?) {}
    override fun componentHidden(e: ComponentEvent?) {}
}

open class WindowAdapter : WindowListener, WindowFocusListener {
    override fun windowOpened(e: WindowEvent?) {}
    override fun windowClosing(e: WindowEvent?) {}
    override fun windowClosed(e: WindowEvent?) {}
    override fun windowIconified(e: WindowEvent?) {}
    override fun windowDeiconified(e: WindowEvent?) {}
    override fun windowActivated(e: WindowEvent?) {}
    override fun windowDeactivated(e: WindowEvent?) {}
    override fun windowGainedFocus(e: WindowEvent?) {}
    override fun windowLostFocus(e: WindowEvent?) {}
}

open class FocusAdapter : FocusListener {
    override fun focusGained(e: FocusEvent?) {}
    override fun focusLost(e: FocusEvent?) {}
}

// ============ Event classes ============

open class InputEvent(source: Any? = null, id: Int = 0, val when_field: Long = 0, val modifiers: Int = 0) : ComponentEvent(source, id) {
    open fun isShiftDown(): Boolean = (modifiers and SHIFT_MASK) != 0
    open fun isControlDown(): Boolean = (modifiers and CTRL_MASK) != 0
    open fun isAltDown(): Boolean = (modifiers and ALT_MASK) != 0
    open fun isMetaDown(): Boolean = (modifiers and META_MASK) != 0
    open fun consume() {}
    open fun isConsumed(): Boolean = false

    companion object {
        const val SHIFT_MASK = 1
        const val CTRL_MASK = 2
        const val META_MASK = 4
        const val ALT_MASK = 8
        const val ALT_GRAPH_MASK = 32
        const val BUTTON1_MASK = 16
        const val BUTTON2_MASK = 8
        const val BUTTON3_MASK = 4
        const val SHIFT_DOWN_MASK = 64
        const val CTRL_DOWN_MASK = 128
        const val META_DOWN_MASK = 256
        const val ALT_DOWN_MASK = 512
        const val BUTTON1_DOWN_MASK = 1024
        const val BUTTON2_DOWN_MASK = 2048
        const val BUTTON3_DOWN_MASK = 4096
        const val ALT_GRAPH_DOWN_MASK = 8192
    }
}

open class KeyEvent(
    source: Any? = null,
    id: Int = KEY_PRESSED,
    when_field: Long = 0,
    modifiers: Int = 0,
    val keyCode: Int = 0,
    val keyChar: Char = CHAR_UNDEFINED,
    val keyLocation: Int = KEY_LOCATION_STANDARD
) : InputEvent(source, id, when_field, modifiers) {

    open fun setKeyCode(keyCode: Int) {}
    open fun setKeyChar(keyChar: Char) {}
    open fun isActionKey(): Boolean = false

    companion object {
        const val KEY_PRESSED = 401
        const val KEY_RELEASED = 402
        const val KEY_TYPED = 400

        const val KEY_LOCATION_UNKNOWN = 0
        const val KEY_LOCATION_STANDARD = 1
        const val KEY_LOCATION_LEFT = 2
        const val KEY_LOCATION_RIGHT = 3
        const val KEY_LOCATION_NUMPAD = 4

        const val CHAR_UNDEFINED: Char = '￿'

        // InputEvent masks (inherited in Java, duplicated here for Kotlin star-import)
        const val SHIFT_DOWN_MASK = 64
        const val CTRL_DOWN_MASK = 128
        const val META_DOWN_MASK = 256
        const val ALT_DOWN_MASK = 512
        const val BUTTON1_DOWN_MASK = 1024
        const val BUTTON2_DOWN_MASK = 2048
        const val BUTTON3_DOWN_MASK = 4096
        const val ALT_GRAPH_DOWN_MASK = 8192

        // Arrow keys
        const val VK_LEFT = 37
        const val VK_UP = 38
        const val VK_RIGHT = 39
        const val VK_DOWN = 40

        // Modifier keys
        const val VK_SHIFT = 16
        const val VK_CONTROL = 17
        const val VK_ALT = 18
        const val VK_META = 157
        const val VK_CAPS_LOCK = 20
        const val VK_NUM_LOCK = 144
        const val VK_SCROLL_LOCK = 145

        // Common keys
        const val VK_ENTER = 10
        const val VK_BACK_SPACE = 8
        const val VK_TAB = 9
        const val VK_ESCAPE = 27
        const val VK_SPACE = 32
        const val VK_DELETE = 127
        const val VK_INSERT = 155
        const val VK_HOME = 36
        const val VK_END = 35
        const val VK_PAGE_UP = 33
        const val VK_PAGE_DOWN = 34
        const val VK_PAUSE = 19
        const val VK_PRINTSCREEN = 154

        // Function keys
        const val VK_F1 = 112
        const val VK_F2 = 113
        const val VK_F3 = 114
        const val VK_F4 = 115
        const val VK_F5 = 116
        const val VK_F6 = 117
        const val VK_F7 = 118
        const val VK_F8 = 119
        const val VK_F9 = 120
        const val VK_F10 = 121
        const val VK_F11 = 122
        const val VK_F12 = 123

        // Number keys
        const val VK_0 = 48
        const val VK_1 = 49
        const val VK_2 = 50
        const val VK_3 = 51
        const val VK_4 = 52
        const val VK_5 = 53
        const val VK_6 = 54
        const val VK_7 = 55
        const val VK_8 = 56
        const val VK_9 = 57

        // Letter keys
        const val VK_A = 65
        const val VK_B = 66
        const val VK_C = 67
        const val VK_D = 68
        const val VK_E = 69
        const val VK_F = 70
        const val VK_G = 71
        const val VK_H = 72
        const val VK_I = 73
        const val VK_J = 74
        const val VK_K = 75
        const val VK_L = 76
        const val VK_M = 77
        const val VK_N = 78
        const val VK_O = 79
        const val VK_P = 80
        const val VK_Q = 81
        const val VK_R = 82
        const val VK_S = 83
        const val VK_T = 84
        const val VK_U = 85
        const val VK_V = 86
        const val VK_W = 87
        const val VK_X = 88
        const val VK_Y = 89
        const val VK_Z = 90

        // Numpad
        const val VK_NUMPAD0 = 96
        const val VK_NUMPAD1 = 97
        const val VK_NUMPAD2 = 98
        const val VK_NUMPAD3 = 99
        const val VK_NUMPAD4 = 100
        const val VK_NUMPAD5 = 101
        const val VK_NUMPAD6 = 102
        const val VK_NUMPAD7 = 103
        const val VK_NUMPAD8 = 104
        const val VK_NUMPAD9 = 105
        const val VK_MULTIPLY = 106
        const val VK_ADD = 107
        const val VK_SUBTRACT = 109
        const val VK_DECIMAL = 110
        const val VK_DIVIDE = 111
        const val VK_SEPARATOR = 108

        // Symbol keys
        const val VK_SEMICOLON = 59
        const val VK_EQUALS = 61
        const val VK_COMMA = 44
        const val VK_MINUS = 45
        const val VK_PERIOD = 46
        const val VK_SLASH = 47
        const val VK_BACK_QUOTE = 192
        const val VK_OPEN_BRACKET = 91
        const val VK_BACK_SLASH = 92
        const val VK_CLOSE_BRACKET = 93
        const val VK_QUOTE = 222
        const val VK_AT = 512
        const val VK_COLON = 513
        const val VK_CIRCUMFLEX = 514
        const val VK_DOLLAR = 515
        const val VK_EXCLAMATION_MARK = 517
        const val VK_PLUS = 521

        // Special
        const val VK_UNDEFINED = 0
        const val VK_WINDOWS = 524
        const val VK_CONTEXT_MENU = 525

        // Editing keys
        const val VK_UNDO = 65483
        const val VK_AGAIN = 65481
        const val VK_FIND = 65488
        const val VK_CUT = 65489
        const val VK_COPY = 65485
        const val VK_PASTE = 65487
        const val VK_STOP = 65480
        const val VK_PROPS = 65482
        const val VK_HELP = 65486
        const val VK_COMPOSE = 65312
        const val VK_KATAKANA = 241
        const val VK_HIRAGANA = 242
        const val VK_ROMAN_CHARACTERS = 245
        const val VK_DEAD_MACRON = 128

        @JvmStatic
        fun getKeyText(keyCode: Int): String = "Key$keyCode"
    }
}

open class MouseEvent(
    source: Any? = null,
    id: Int = MOUSE_CLICKED,
    when_field: Long = 0,
    modifiers: Int = 0,
    val x: Int = 0,
    val y: Int = 0,
    val clickCount: Int = 0,
    val popupTrigger: Boolean = false,
    val button: Int = NOBUTTON
) : InputEvent(source, id, when_field, modifiers) {

    open fun getXOnScreen(): Int = x
    open fun getYOnScreen(): Int = y
    open fun getPoint(): java.awt.Point = java.awt.Point(x, y)

    companion object {
        const val MOUSE_CLICKED = 500
        const val MOUSE_PRESSED = 501
        const val MOUSE_RELEASED = 502
        const val MOUSE_MOVED = 503
        const val MOUSE_ENTERED = 504
        const val MOUSE_EXITED = 505
        const val MOUSE_DRAGGED = 506
        const val MOUSE_WHEEL = 507

        const val NOBUTTON = 0
        const val BUTTON1 = 1
        const val BUTTON2 = 2
        const val BUTTON3 = 3
    }
}

open class MouseWheelEvent(
    source: Any? = null,
    id: Int = MouseEvent.MOUSE_WHEEL,
    when_field: Long = 0,
    modifiers: Int = 0,
    x: Int = 0,
    y: Int = 0,
    clickCount: Int = 0,
    popupTrigger: Boolean = false,
    val scrollType: Int = WHEEL_UNIT_SCROLL,
    val scrollAmount: Int = 3,
    val wheelRotation: Int = 0
) : MouseEvent(source, id, when_field, modifiers, x, y, clickCount, popupTrigger) {

    open fun getPreciseWheelRotation(): Double = wheelRotation.toDouble()

    companion object {
        const val WHEEL_UNIT_SCROLL = 0
        const val WHEEL_BLOCK_SCROLL = 1
    }
}

open class ComponentEvent(source: Any? = null, id: Int = COMPONENT_RESIZED) : AWTEvent(source, id) {
    open fun getComponent(): Component? = source as? Component

    companion object {
        const val COMPONENT_FIRST = 100
        const val COMPONENT_LAST = 103
        const val COMPONENT_MOVED = 100
        const val COMPONENT_RESIZED = 101
        const val COMPONENT_SHOWN = 102
        const val COMPONENT_HIDDEN = 103
    }
}

open class WindowEvent(source: Any? = null, id: Int = WINDOW_OPENED) : ComponentEvent(source, id) {
    open fun getWindow(): java.awt.Window? = source as? java.awt.Window

    companion object {
        const val WINDOW_FIRST = 200
        const val WINDOW_OPENED = 200
        const val WINDOW_CLOSING = 201
        const val WINDOW_CLOSED = 202
        const val WINDOW_ICONIFIED = 203
        const val WINDOW_DEICONIFIED = 204
        const val WINDOW_ACTIVATED = 205
        const val WINDOW_DEACTIVATED = 206
        const val WINDOW_GAINED_FOCUS = 207
        const val WINDOW_LOST_FOCUS = 208
        const val WINDOW_STATE_CHANGED = 209
        const val WINDOW_LAST = 209
    }
}

open class FocusEvent(source: Any? = null, id: Int = FOCUS_GAINED, val temporary: Boolean = false) : ComponentEvent(source, id) {

    companion object {
        const val FOCUS_GAINED = 1004
        const val FOCUS_LOST = 1005
    }
}

open class ActionEvent(
    source: Any? = null,
    id: Int = ACTION_PERFORMED,
    val command: String? = null,
    val actionModifiers: Int = 0
) : AWTEvent(source, id) {

    constructor(source: Any?, id: Int, command: String?) : this(source, id, command, 0)

    open fun getModifiers(): Int = actionModifiers

    companion object {
        const val ACTION_PERFORMED = 1001
        const val ACTION_FIRST = 1001
        const val ACTION_LAST = 1001
        const val SHIFT_MASK = 1
        const val CTRL_MASK = 2
        const val META_MASK = 4
        const val ALT_MASK = 8
    }
}

open class ItemEvent(
    source: Any? = null,
    id: Int = ITEM_STATE_CHANGED,
    val item: Any? = null,
    val stateChange: Int = SELECTED
) : AWTEvent(source, id) {


    companion object {
        const val ITEM_STATE_CHANGED = 701
        const val SELECTED = 1
        const val DESELECTED = 2
    }
}

open class AdjustmentEvent(
    source: Any? = null,
    id: Int = ADJUSTMENT_VALUE_CHANGED,
    val adjustmentType: Int = 0,
    val value: Int = 0
) : AWTEvent(source, id) {


    companion object {
        const val ADJUSTMENT_VALUE_CHANGED = 601
        const val UNIT_INCREMENT = 1
        const val UNIT_DECREMENT = 2
        const val BLOCK_DECREMENT = 3
        const val BLOCK_INCREMENT = 4
        const val TRACK = 5
    }
}
