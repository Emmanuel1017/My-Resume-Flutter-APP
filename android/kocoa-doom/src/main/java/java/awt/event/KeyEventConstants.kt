@file:Suppress("unused")
package java.awt.event

/**
 * Top-level object containing KeyEvent and InputEvent constants.
 * Needed because Kotlin 2.x does not support star-importing companion object members
 * via `import ClassName.*` syntax.
 */
object KeyEventConstants {
    // Key event types
    const val KEY_PRESSED = 401
    const val KEY_RELEASED = 402
    const val KEY_TYPED = 400

    // Key locations
    const val KEY_LOCATION_UNKNOWN = 0
    const val KEY_LOCATION_STANDARD = 1
    const val KEY_LOCATION_LEFT = 2
    const val KEY_LOCATION_RIGHT = 3
    const val KEY_LOCATION_NUMPAD = 4

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

    // InputEvent masks
    const val SHIFT_MASK = 1
    const val CTRL_MASK = 2
    const val META_MASK = 4
    const val ALT_MASK = 8
    const val SHIFT_DOWN_MASK = 64
    const val CTRL_DOWN_MASK = 128
    const val META_DOWN_MASK = 256
    const val ALT_DOWN_MASK = 512
    const val BUTTON1_DOWN_MASK = 1024
    const val BUTTON2_DOWN_MASK = 2048
    const val BUTTON3_DOWN_MASK = 4096
}
