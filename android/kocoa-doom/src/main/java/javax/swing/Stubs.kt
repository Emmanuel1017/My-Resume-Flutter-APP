@file:Suppress("UNUSED_PARAMETER", "unused")
package javax.swing

import java.awt.*
import java.awt.event.*

// ============ JComponent base ============

open class JComponent : Component() {
    open var isDoubleBuffered: Boolean = true
    open var isOpaque: Boolean = true

    open fun isOptimizedDrawingEnabled(): Boolean = true
    open fun setBorder(border: Any?) {}
    open fun getBorder(): Any? = null
    open fun setToolTipText(text: String?) {}
    open fun getToolTipText(): String? = null
    open fun paintComponent(g: Graphics?) {}
    open fun setAlignmentX(alignmentX: Float) {}
    open fun setAlignmentY(alignmentY: Float) {}
    override fun getPreferredSize(): Dimension = preferredSize ?: Dimension(0, 0)
    override fun setPreferredSize(d: Dimension?) { preferredSize = d }

    companion object {
        const val WHEN_FOCUSED = 0
        const val WHEN_ANCESTOR_OF_FOCUSED_COMPONENT = 1
        const val WHEN_IN_FOCUSED_WINDOW = 2
    }
}

// ============ JFrame ============

open class JFrame : Frame {
    var defaultCloseOperation: Int = EXIT_ON_CLOSE

    constructor() : super("")
    constructor(title: String?) : super(title ?: "")
    constructor(gc: GraphicsConfiguration?) : super("")

    open fun getContentPane(): Container = Container()
    open fun setContentPane(contentPane: Container?) {}
    open fun getRootPane(): JRootPane = JRootPane()
    open fun getJMenuBar(): JMenuBar? = null
    open fun setJMenuBar(menubar: JMenuBar?) {}
    open fun getGlassPane(): Component = Component()
    open fun setGlassPane(glassPane: Component?) {}
    open fun getLayeredPane(): JLayeredPane = JLayeredPane()
    open fun setLayeredPane(layeredPane: JLayeredPane?) {}

    companion object {
        const val EXIT_ON_CLOSE = 3
        const val HIDE_ON_CLOSE = 1
        const val DISPOSE_ON_CLOSE = 2
        const val DO_NOTHING_ON_CLOSE = 0
    }
}

// ============ JPanel ============

open class JPanel() : JComponent() {
    constructor(layout: LayoutManager?) : this()
    constructor(isDoubleBuffered: Boolean) : this()
    constructor(layout: LayoutManager?, isDoubleBuffered: Boolean) : this()

    open fun add(comp: Component?): Component? = comp
    open fun add(comp: Component?, constraints: Any?) {}
    open fun add(name: String?, comp: Component?): Component? = comp
    open fun remove(comp: Component?) {}
    open fun removeAll() {}
    open fun setLayout(mgr: LayoutManager?) {}
    open fun getLayout(): LayoutManager? = null
    open fun getComponents(): Array<Component> = emptyArray()
    open fun getComponentCount(): Int = 0
    override fun revalidate() {}
    override fun repaint() {}
}

// ============ JLabel ============

open class JLabel : JComponent {
    var text: String? = null
    var icon: Icon? = null
    var horizontalAlignment: Int = LEFT

    constructor()
    constructor(text: String?) { this.text = text }
    constructor(text: String?, horizontalAlignment: Int) { this.text = text; this.horizontalAlignment = horizontalAlignment }
    constructor(icon: Icon?) { this.icon = icon }
    constructor(icon: Icon?, horizontalAlignment: Int) { this.icon = icon; this.horizontalAlignment = horizontalAlignment }
    constructor(text: String?, icon: Icon?, horizontalAlignment: Int) { this.text = text; this.icon = icon; this.horizontalAlignment = horizontalAlignment }
    companion object {
        const val LEFT = 2
        const val CENTER = 0
        const val RIGHT = 4
        const val LEADING = 10
        const val TRAILING = 11
    }
}

// ============ JButton ============

open class JButton : JComponent {
    var text: String? = null

    constructor() : super()
    constructor(text: String?) : super() { this.text = text }
    constructor(icon: Icon?) : super()
    open fun addActionListener(l: ActionListener?) {}
    open fun removeActionListener(l: ActionListener?) {}
    override fun setEnabled(b: Boolean) { isEnabled = b }
}

// ============ JTextField / JTextArea ============

open class JTextField : JComponent {
    var text: String? = ""
    var columns: Int = 0

    constructor()
    constructor(columns: Int) { this.columns = columns }
    constructor(text: String?) { this.text = text }
    constructor(text: String?, columns: Int) { this.text = text; this.columns = columns }
    open fun addActionListener(l: ActionListener?) {}
}

open class JTextArea : JComponent {
    var text: String? = ""
    var rows: Int = 0
    var columns: Int = 0

    constructor()
    constructor(text: String?)  { this.text = text }
    constructor(rows: Int, columns: Int) { this.rows = rows; this.columns = columns }
    constructor(text: String?, rows: Int, columns: Int) { this.text = text; this.rows = rows; this.columns = columns }
    open fun append(str: String?) { text = (text ?: "") + (str ?: "") }
    open fun setEditable(b: Boolean) {}
    open fun isEditable(): Boolean = true
    open fun setLineWrap(wrap: Boolean) {}
    open fun setWrapStyleWord(word: Boolean) {}
}

// ============ JScrollPane ============

open class JScrollPane : JComponent {
    constructor()
    constructor(view: Component?)
    constructor(vsbPolicy: Int, hsbPolicy: Int)
    constructor(view: Component?, vsbPolicy: Int, hsbPolicy: Int)

    open fun setViewportView(view: Component?) {}
    open fun getViewport(): JViewport = JViewport()

    companion object {
        const val VERTICAL_SCROLLBAR_AS_NEEDED = 20
        const val VERTICAL_SCROLLBAR_NEVER = 21
        const val VERTICAL_SCROLLBAR_ALWAYS = 22
        const val HORIZONTAL_SCROLLBAR_AS_NEEDED = 30
        const val HORIZONTAL_SCROLLBAR_NEVER = 31
        const val HORIZONTAL_SCROLLBAR_ALWAYS = 32
    }
}

open class JViewport : JComponent() {
    open fun getView(): Component? = null
    open fun setView(view: Component?) {}
}

// ============ JDialog ============

open class JDialog : Dialog {
    constructor() : super()
    constructor(owner: Frame?) : super(owner)
    constructor(owner: Frame?, title: String?) : super(owner, title)
    constructor(owner: Frame?, title: String?, modal: Boolean) : super(owner, title, modal)

    open fun getContentPane(): Container = Container()
    open fun setContentPane(contentPane: Container?) {}
}

// ============ JOptionPane (static utility) ============

open class JOptionPane {
    companion object {
        const val DEFAULT_OPTION = -1
        const val YES_NO_OPTION = 0
        const val YES_NO_CANCEL_OPTION = 1
        const val OK_CANCEL_OPTION = 2
        const val YES_OPTION = 0
        const val NO_OPTION = 1
        const val CANCEL_OPTION = 2
        const val OK_OPTION = 0
        const val CLOSED_OPTION = -1
        const val ERROR_MESSAGE = 0
        const val INFORMATION_MESSAGE = 1
        const val WARNING_MESSAGE = 2
        const val QUESTION_MESSAGE = 3
        const val PLAIN_MESSAGE = -1

        @JvmStatic
        fun showMessageDialog(parentComponent: Component?, message: Any?) {}

        @JvmStatic
        fun showMessageDialog(parentComponent: Component?, message: Any?, title: String?, messageType: Int) {}

        @JvmStatic
        fun showConfirmDialog(parentComponent: Component?, message: Any?): Int = YES_OPTION

        @JvmStatic
        fun showConfirmDialog(parentComponent: Component?, message: Any?, title: String?, optionType: Int): Int = YES_OPTION

        @JvmStatic
        fun showInputDialog(parentComponent: Component?, message: Any?): String? = null

        @JvmStatic
        fun showInputDialog(message: Any?): String? = null
    }
}

// ============ JMenuBar / JMenu / JMenuItem ============

open class JMenuBar : JComponent() {
    open fun add(menu: JMenu?): JMenu? = menu
    open fun getMenuCount(): Int = 0
    open fun getMenu(index: Int): JMenu? = null
}

open class JMenu : JMenuItem {
    constructor() : super()
    constructor(s: String?) : super(s)

    open fun add(menuItem: JMenuItem?): JMenuItem? = menuItem
    open fun add(s: String?): JMenuItem = JMenuItem(s)
    open fun addSeparator() {}
    open fun getItemCount(): Int = 0
    open fun getItem(index: Int): JMenuItem? = null
}

open class JMenuItem : JComponent {
    var text: String? = null

    constructor() : super()
    constructor(text: String?) : super() { this.text = text }
    constructor(icon: Icon?) : super()
    open fun addActionListener(l: ActionListener?) {}
    open fun removeActionListener(l: ActionListener?) {}
    override fun setEnabled(b: Boolean) { isEnabled = b }
    open fun setAccelerator(keyStroke: KeyStroke?) {}
}

open class JCheckBoxMenuItem : JMenuItem {
    var state: Boolean = false

    constructor() : super()
    constructor(text: String?) : super(text)
    constructor(text: String?, selected: Boolean) : super(text) { this.state = selected }

    open fun isSelected(): Boolean = state
}

// ============ Other Swing components ============

open class JComboBox<E> : JComponent() {
    open fun addItem(item: E) {}
    open fun removeItem(item: Any?) {}
    open fun removeAllItems() {}
    open fun getSelectedItem(): Any? = null
    open fun setSelectedItem(item: Any?) {}
    open fun getSelectedIndex(): Int = -1
    open fun setSelectedIndex(index: Int) {}
    open fun getItemCount(): Int = 0
    open fun getItemAt(index: Int): E? = null
    open fun addActionListener(l: ActionListener?) {}
}

open class JCheckBox : JComponent {
    var text: String? = null
    var selected: Boolean = false

    constructor()
    constructor(text: String?) { this.text = text }
    constructor(text: String?, selected: Boolean) { this.text = text; this.selected = selected }

    open fun isSelected(): Boolean = selected
}

open class JSlider : JComponent {
    var value: Int = 50
    var minimum: Int = 0
    var maximum: Int = 100

    constructor()
    constructor(orientation: Int)
    constructor(min: Int, max: Int) { minimum = min; maximum = max }
    constructor(min: Int, max: Int, value: Int) { minimum = min; maximum = max; this.value = value }
    constructor(orientation: Int, min: Int, max: Int, value: Int) { minimum = min; maximum = max; this.value = value }
}

open class JProgressBar : JComponent {
    var value: Int = 0
    var minimum: Int = 0
    var maximum: Int = 100

    constructor()
    constructor(orient: Int)
    constructor(min: Int, max: Int) { minimum = min; maximum = max }
    open fun setStringPainted(b: Boolean) {}
    open fun setIndeterminate(newValue: Boolean) {}
    open fun getString(): String? = null
    open fun setString(s: String?) {}
}

open class JTabbedPane : JComponent() {
    open fun addTab(title: String?, component: Component?) {}
    open fun addTab(title: String?, icon: Icon?, component: Component?) {}
    open fun addTab(title: String?, icon: Icon?, component: Component?, tip: String?) {}
    open fun getSelectedIndex(): Int = -1
    open fun setSelectedIndex(index: Int) {}
    open fun getTabCount(): Int = 0
}

open class JFileChooser : JComponent() {
    open fun showOpenDialog(parent: Component?): Int = CANCEL_OPTION
    open fun showSaveDialog(parent: Component?): Int = CANCEL_OPTION
    open fun getSelectedFile(): java.io.File? = null
    open fun setSelectedFile(file: java.io.File?) {}
    open fun setCurrentDirectory(dir: java.io.File?) {}

    companion object {
        const val APPROVE_OPTION = 0
        const val CANCEL_OPTION = 1
        const val ERROR_OPTION = -1
        const val OPEN_DIALOG = 0
        const val SAVE_DIALOG = 1
    }
}

open class JSplitPane : JComponent() {
    companion object {
        const val HORIZONTAL_SPLIT = 1
        const val VERTICAL_SPLIT = 0
    }
}

open class JToolBar : JComponent {
    constructor()
    constructor(orientation: Int)
    constructor(name: String?)

    open fun add(comp: Component?): Component? = comp
    open fun addSeparator() {}
    open fun setFloatable(b: Boolean) {}
}

// ============ Timer ============

open class Timer(@JvmField val delay: Int, val listener: ActionListener?) {
    @JvmField var isRunning: Boolean = false
    @JvmField var isRepeats: Boolean = true
    @JvmField var initialDelay: Int = delay

    open fun start() { isRunning = true }
    open fun stop() { isRunning = false }
    open fun restart() { isRunning = true }
    open fun isRunning(): Boolean = isRunning
    open fun setRepeats(flag: Boolean) { isRepeats = flag }
    open fun setInitialDelay(initialDelay: Int) { this.initialDelay = initialDelay }
    open fun setDelay(delay: Int) {}
    open fun getDelay(): Int = delay
}

// ============ Misc types ============

interface Icon {
    fun paintIcon(c: Component?, g: Graphics?, x: Int, y: Int)
    fun getIconWidth(): Int
    fun getIconHeight(): Int
}

open class ImageIcon : Icon {
    constructor()
    constructor(filename: String?)
    constructor(image: Image?)
    constructor(imageData: ByteArray?)

    open fun getImage(): Image? = null
    open fun setImage(image: Image?) {}
    override fun paintIcon(c: Component?, g: Graphics?, x: Int, y: Int) {}
    override fun getIconWidth(): Int = 0
    override fun getIconHeight(): Int = 0
}

open class KeyStroke {
    companion object {
        @JvmStatic
        fun getKeyStroke(keyCode: Int, modifiers: Int): KeyStroke = KeyStroke()

        @JvmStatic
        fun getKeyStroke(keyChar: Char): KeyStroke = KeyStroke()

        @JvmStatic
        fun getKeyStroke(s: String?): KeyStroke? = KeyStroke()
    }
}

open class SwingUtilities {
    companion object {
        @JvmStatic
        fun invokeLater(doRun: Runnable?) { doRun?.run() }

        @JvmStatic
        fun invokeAndWait(doRun: Runnable?) { doRun?.run() }

        @JvmStatic
        fun isEventDispatchThread(): Boolean = true
    }
}

open class JRootPane : JComponent()
open class JLayeredPane : JComponent()

open class BoxLayout(target: Container?, axis: Int) : LayoutManager {
    companion object {
        const val X_AXIS = 0
        const val Y_AXIS = 1
        const val LINE_AXIS = 2
        const val PAGE_AXIS = 3
    }
}

open class Box(axis: Int) : JComponent() {
    companion object {
        @JvmStatic
        fun createHorizontalBox(): Box = Box(BoxLayout.X_AXIS)

        @JvmStatic
        fun createVerticalBox(): Box = Box(BoxLayout.Y_AXIS)

        @JvmStatic
        fun createHorizontalStrut(width: Int): Component = Component()

        @JvmStatic
        fun createVerticalStrut(height: Int): Component = Component()

        @JvmStatic
        fun createHorizontalGlue(): Component = Component()

        @JvmStatic
        fun createVerticalGlue(): Component = Component()

        @JvmStatic
        fun createRigidArea(d: Dimension?): Component = Component()
    }
}

// ============ SwingConstants ============

interface SwingConstants {
    companion object {
        const val CENTER = 0
        const val TOP = 1
        const val LEFT = 2
        const val BOTTOM = 3
        const val RIGHT = 4
        const val NORTH = 1
        const val NORTH_EAST = 2
        const val EAST = 3
        const val SOUTH_EAST = 4
        const val SOUTH = 5
        const val SOUTH_WEST = 6
        const val WEST = 7
        const val NORTH_WEST = 8
        const val HORIZONTAL = 0
        const val VERTICAL = 1
        const val LEADING = 10
        const val TRAILING = 11
    }
}

// ============ UIManager ============

open class UIManager {
    companion object {
        @JvmStatic
        fun setLookAndFeel(className: String?) {}

        @JvmStatic
        fun setLookAndFeel(laf: Any?) {}

        @JvmStatic
        fun getSystemLookAndFeelClassName(): String = ""

        @JvmStatic
        fun getCrossPlatformLookAndFeelClassName(): String = ""

        @JvmStatic
        fun put(key: Any?, value: Any?) {}

        @JvmStatic
        fun get(key: Any?): Any? = null

        @JvmStatic
        fun getColor(key: Any?): Color? = null

        @JvmStatic
        fun getFont(key: Any?): Font? = null

        @JvmStatic
        fun getInstalledLookAndFeels(): Array<LookAndFeelInfo> = emptyArray()
    }

    open class LookAndFeelInfo(val name: String?, val className: String?) {
    }
}

// ============ BorderFactory ============

open class BorderFactory {
    companion object {
        @JvmStatic fun createEmptyBorder(): Any? = null
        @JvmStatic fun createEmptyBorder(top: Int, left: Int, bottom: Int, right: Int): Any? = null
        @JvmStatic fun createLineBorder(color: Color?): Any? = null
        @JvmStatic fun createLineBorder(color: Color?, thickness: Int): Any? = null
        @JvmStatic fun createTitledBorder(title: String?): Any? = null
        @JvmStatic fun createEtchedBorder(): Any? = null
        @JvmStatic fun createBevelBorder(type: Int): Any? = null
        @JvmStatic fun createCompoundBorder(outsideBorder: Any?, insideBorder: Any?): Any? = null
        @JvmStatic fun createRaisedBevelBorder(): Any? = null
        @JvmStatic fun createLoweredBevelBorder(): Any? = null
    }
}
