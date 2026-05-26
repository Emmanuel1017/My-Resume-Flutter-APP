@file:Suppress("UNUSED_PARAMETER", "unused")
package javax.sound.sampled

import java.io.File
import java.io.InputStream

// ============ AudioFormat ============

open class AudioFormat {
    val encoding: Encoding
    val sampleRate: Float
    val sampleSizeInBits: Int
    val channels: Int
    val frameSize: Int
    val frameRate: Float
    val bigEndian: Boolean

    constructor(
        encoding: Encoding,
        sampleRate: Float,
        sampleSizeInBits: Int,
        channels: Int,
        frameSize: Int,
        frameRate: Float,
        bigEndian: Boolean
    ) {
        this.encoding = encoding
        this.sampleRate = sampleRate
        this.sampleSizeInBits = sampleSizeInBits
        this.channels = channels
        this.frameSize = frameSize
        this.frameRate = frameRate
        this.bigEndian = bigEndian
    }

    constructor(sampleRate: Float, sampleSizeInBits: Int, channels: Int, signed: Boolean, bigEndian: Boolean) {
        this.encoding = if (signed) Encoding.PCM_SIGNED else Encoding.PCM_UNSIGNED
        this.sampleRate = sampleRate
        this.sampleSizeInBits = sampleSizeInBits
        this.channels = channels
        this.frameSize = (sampleSizeInBits / 8) * channels
        this.frameRate = sampleRate
        this.bigEndian = bigEndian
    }
    open fun isBigEndian(): Boolean = bigEndian
    open fun matches(format: AudioFormat?): Boolean = true

    open class Encoding(val name: String) {
        companion object {
            @JvmField val PCM_SIGNED = Encoding("PCM_SIGNED")
            @JvmField val PCM_UNSIGNED = Encoding("PCM_UNSIGNED")
            @JvmField val PCM_FLOAT = Encoding("PCM_FLOAT")
            @JvmField val ULAW = Encoding("ULAW")
            @JvmField val ALAW = Encoding("ALAW")
        }

        override fun toString(): String = name
        override fun equals(other: Any?): Boolean = other is Encoding && other.name == name
        override fun hashCode(): Int = name.hashCode()
    }
}

// ============ Line interfaces ============

interface Line : AutoCloseable {
    fun open()
    override fun close()
    fun isOpen(): Boolean
    fun getLineInfo(): Line.Info
    fun isControlSupported(type: Control.Type?): Boolean = false
    fun getControl(type: Control.Type?): Control? = null
    fun getControls(): Array<Control> = emptyArray()
    fun addLineListener(listener: LineListener?) {}
    fun removeLineListener(listener: LineListener?) {}

    open class Info(val lineClass: Class<*>? = null) {
        open fun matches(info: Info?): Boolean = true
    }
}

interface DataLine : Line {
    val isActive: Boolean get() = false
    val isRunning: Boolean get() = false

    fun drain()
    fun flush()
    fun start()
    fun stop()
    fun getFormat(): AudioFormat
    fun getBufferSize(): Int
    fun available(): Int
    fun getFramePosition(): Int
    fun getFrameLength(): Int = 0
    fun getLongFramePosition(): Long
    fun getMicrosecondPosition(): Long
    fun getLevel(): Float

    open class Info : Line.Info {
        val format: AudioFormat?
        val bufferSize: Int

        constructor(lineClass: Class<*>?, format: AudioFormat?) : super(lineClass) {
            this.format = format
            this.bufferSize = -1
        }

        constructor(lineClass: Class<*>?, format: AudioFormat?, bufferSize: Int) : super(lineClass) {
            this.format = format
            this.bufferSize = bufferSize
        }

        constructor(lineClass: Class<*>?, formats: Array<AudioFormat>?, minBufferSize: Int, maxBufferSize: Int) : super(lineClass) {
            this.format = formats?.firstOrNull()
            this.bufferSize = maxBufferSize
        }

        open fun getFormats(): Array<AudioFormat> = if (format != null) arrayOf(format) else emptyArray()
        open fun isFormatSupported(format: AudioFormat?): Boolean = true
        open fun getMinBufferSize(): Int = 0
        open fun getMaxBufferSize(): Int = bufferSize
    }
}

interface SourceDataLine : DataLine {
    fun open(format: AudioFormat?)
    fun open(format: AudioFormat?, bufferSize: Int)
    fun write(b: ByteArray?, off: Int, len: Int): Int
}

interface TargetDataLine : DataLine {
    fun open(format: AudioFormat?)
    fun open(format: AudioFormat?, bufferSize: Int)
    fun read(b: ByteArray?, off: Int, len: Int): Int
}

interface Clip : DataLine {
    fun open(format: AudioFormat?, data: ByteArray?, offset: Int, bufferSize: Int)
    fun open(stream: AudioInputStream?)
    fun getMicrosecondLength(): Long
    fun setFramePosition(frames: Int)
    fun setMicrosecondPosition(microseconds: Long)
    fun setLoopPoints(start: Int, end: Int)
    fun loop(count: Int)

    companion object {
        const val LOOP_CONTINUOUSLY = -1
    }
}

var Clip.framePosition: Int
    get() = getFramePosition()
    set(value) { setFramePosition(value) }

interface Mixer : Line {
    fun getMixerInfo(): Mixer.Info
    fun getSourceLineInfo(): Array<Line.Info>
    fun getTargetLineInfo(): Array<Line.Info>
    fun getSourceLineInfo(info: Line.Info?): Array<Line.Info>
    fun getTargetLineInfo(info: Line.Info?): Array<Line.Info>
    fun isLineSupported(info: Line.Info?): Boolean
    fun getLine(info: Line.Info?): Line
    fun getMaxLines(info: Line.Info?): Int
    fun getSourceLines(): Array<Line>
    fun getTargetLines(): Array<Line>
    fun synchronize(lines: Array<Line>?, maintainSync: Boolean)
    fun unsynchronize(lines: Array<Line>?)

    open class Info(@JvmField val name: String?, @JvmField val vendor: String?, @JvmField val description: String?, @JvmField val version: String?) {
    }
}

interface Port : Line {
    open class Info(@JvmField val name: String?, @JvmField val isSource: Boolean) : Line.Info() {
        companion object {
            @JvmField val SPEAKER = Info("SPEAKER", false)
            @JvmField val HEADPHONE = Info("HEADPHONE", false)
            @JvmField val MICROPHONE = Info("MICROPHONE", true)
            @JvmField val LINE_IN = Info("LINE_IN", true)
            @JvmField val LINE_OUT = Info("LINE_OUT", false)
            @JvmField val COMPACT_DISC = Info("COMPACT_DISC", true)
        }

        open fun getName(): String = name ?: ""
        open fun isSource(): Boolean = isSource
    }
}

// ============ Controls ============

abstract class Control(val type: Control.Type?) {
    open class Type(val name: String?) {
        override fun toString(): String = name ?: ""
    }
}

open class FloatControl(
    type: Type,
    val minimum: Float = 0f,
    val maximum: Float = 1f,
    val precision: Float = 0.01f,
    val updatePeriod: Int = -1,
    val initialValue: Float = 0f,
    val units: String? = "",
    val minLabel: String? = "",
    val midLabel: String? = "",
    val maxLabel: String? = ""
) : Control(type) {
    var value: Float = initialValue
    open class Type(name: String?) : Control.Type(name) {
        companion object {
            @JvmField val MASTER_GAIN = Type("Master Gain")
            @JvmField val AUX_SEND = Type("AUX Send")
            @JvmField val AUX_RETURN = Type("AUX Return")
            @JvmField val REVERB_SEND = Type("Reverb Send")
            @JvmField val REVERB_RETURN = Type("Reverb Return")
            @JvmField val VOLUME = Type("Volume")
            @JvmField val PAN = Type("Pan")
            @JvmField val BALANCE = Type("Balance")
            @JvmField val SAMPLE_RATE = Type("Sample Rate")
        }
    }
}

open class BooleanControl(
    type: Type,
    initialValue: Boolean = false,
    val trueStateLabel: String? = "true",
    val falseStateLabel: String? = "false"
) : Control(type) {
    var value: Boolean = initialValue
    open fun getStateLabel(state: Boolean): String = if (state) trueStateLabel ?: "true" else falseStateLabel ?: "false"

    open class Type(name: String?) : Control.Type(name) {
        companion object {
            @JvmField val MUTE = Type("Mute")
            @JvmField val APPLY_REVERB = Type("Apply Reverb")
        }
    }
}

open class EnumControl(type: Type, val values: Array<Any>? = null, val initialValue: Any? = null) : Control(type) {
    var value: Any? = initialValue

    open class Type(name: String?) : Control.Type(name) {
        companion object {
            @JvmField val REVERB = Type("Reverb")
        }
    }
}

open class CompoundControl(type: Type, val memberControls: Array<Control>? = null) : Control(type) {

    open class Type(name: String?) : Control.Type(name)
}

// ============ LineEvent ============

open class LineEvent(val line: Line?, val type: Type?, val position: Long = 0) {
    open fun getFramePosition(): Long = position

    open class Type(val name: String?) {
        companion object {
            @JvmField val OPEN = Type("Open")
            @JvmField val CLOSE = Type("Close")
            @JvmField val START = Type("Start")
            @JvmField val STOP = Type("Stop")
        }

        override fun toString(): String = name ?: ""
        override fun equals(other: Any?): Boolean = other is Type && other.name == name
        override fun hashCode(): Int = name?.hashCode() ?: 0
    }
}

interface LineListener {
    fun update(event: LineEvent?)
}

// ============ AudioInputStream ============

open class AudioInputStream(
    var format: AudioFormat = AudioFormat(44100f, 16, 2, true, false),
    var frameLength: Long = 0
) : InputStream() {

    constructor(stream: InputStream?, format: AudioFormat?, length: Long) : this(
        format ?: AudioFormat(44100f, 16, 2, true, false),
        length
    )

    constructor(targetDataLine: TargetDataLine?) : this()
    override fun read(): Int = -1
    override fun read(b: ByteArray?): Int = -1
    override fun read(b: ByteArray?, off: Int, len: Int): Int = -1
    override fun skip(n: Long): Long = 0
    override fun available(): Int = 0
    override fun close() {}
    override fun markSupported(): Boolean = false
}

// ============ AudioSystem ============

object AudioSystem {
    const val NOT_SPECIFIED = -1

    private val activeLines = mutableListOf<StubSourceDataLine>()

    @JvmStatic
    fun stopAll() {
        synchronized(activeLines) {
            for (line in activeLines) {
                line.close()
            }
            activeLines.clear()
        }
    }

    @JvmStatic
    fun getLine(info: Line.Info?): Line {
        val line = StubSourceDataLine()
        synchronized(activeLines) { activeLines.add(line) }
        return line
    }

    @JvmStatic
    fun getClip(): Clip = StubClip()

    @JvmStatic
    fun getClip(mixerInfo: Mixer.Info?): Clip = StubClip()

    @JvmStatic
    fun getSourceDataLine(format: AudioFormat?): SourceDataLine {
        val line = StubSourceDataLine()
        synchronized(activeLines) { activeLines.add(line) }
        return line
    }

    @JvmStatic
    fun getSourceDataLine(format: AudioFormat?, mixerInfo: Mixer.Info?): SourceDataLine {
        val line = StubSourceDataLine()
        synchronized(activeLines) { activeLines.add(line) }
        return line
    }

    @JvmStatic
    fun getTargetDataLine(format: AudioFormat?): TargetDataLine = StubTargetDataLine()

    @JvmStatic
    fun getTargetDataLine(format: AudioFormat?, mixerInfo: Mixer.Info?): TargetDataLine = StubTargetDataLine()

    @JvmStatic
    fun getMixerInfo(): Array<Mixer.Info> = emptyArray()

    @JvmStatic
    fun getMixer(info: Mixer.Info?): Mixer? = null

    @JvmStatic
    fun getAudioInputStream(stream: InputStream?): AudioInputStream = AudioInputStream()

    @JvmStatic
    fun getAudioInputStream(file: File?): AudioInputStream = AudioInputStream()

    @JvmStatic
    fun getAudioInputStream(format: AudioFormat?, stream: AudioInputStream?): AudioInputStream = AudioInputStream()

    @JvmStatic
    fun getAudioInputStream(targetEncoding: AudioFormat.Encoding?, stream: AudioInputStream?): AudioInputStream = AudioInputStream()

    @JvmStatic
    fun isLineSupported(info: Line.Info?): Boolean = true

    @JvmStatic
    fun isConversionSupported(targetFormat: AudioFormat?, sourceFormat: AudioFormat?): Boolean = false

    @JvmStatic
    fun isConversionSupported(targetEncoding: AudioFormat.Encoding?, sourceFormat: AudioFormat?): Boolean = false

    @JvmStatic
    fun getAudioFileFormat(file: File?): AudioFileFormat = AudioFileFormat()

    @JvmStatic
    fun getAudioFileFormat(stream: InputStream?): AudioFileFormat = AudioFileFormat()

    @JvmStatic
    fun write(stream: AudioInputStream?, fileType: AudioFileFormat.Type?, out: File?): Int = 0

    @JvmStatic
    fun write(stream: AudioInputStream?, fileType: AudioFileFormat.Type?, out: java.io.OutputStream?): Int = 0

    @JvmStatic
    fun getAudioFileTypes(): Array<AudioFileFormat.Type> = emptyArray()

    @JvmStatic
    fun isFileTypeSupported(fileType: AudioFileFormat.Type?): Boolean = false
}

// ============ AudioFileFormat ============

open class AudioFileFormat {
    open fun getByteLength(): Int = -1

    open class Type(val name: String?, val extension: String?) {
        companion object {
            @JvmField val WAVE = Type("WAVE", "wav")
            @JvmField val AU = Type("AU", "au")
            @JvmField val AIFF = Type("AIFF", "aiff")
            @JvmField val SND = Type("SND", "snd")
        }

        override fun toString(): String = name ?: ""
        override fun equals(other: Any?): Boolean = other is Type && other.name == name
        override fun hashCode(): Int = name?.hashCode() ?: 0
    }
}

// ============ Exceptions ============

open class LineUnavailableException(message: String? = null) : Exception(message)
open class UnsupportedAudioFileException(message: String? = null) : Exception(message)

// ============ Stub implementations ============

private class StubSourceDataLine : SourceDataLine {
    private var open = false
    private var audioTrack: android.media.AudioTrack? = null
    private var audioFormat: AudioFormat? = null
    private var swapBuffer: ByteArray? = null

    override val isActive: Boolean get() = audioTrack?.playState == android.media.AudioTrack.PLAYSTATE_PLAYING
    override val isRunning: Boolean get() = isActive

    override fun open() { open = true }

    override fun open(format: AudioFormat?) { open(format, 4096) }

    override fun open(format: AudioFormat?, bufferSize: Int) {
        open = true
        audioFormat = format
        if (format == null) return

        try {
            val sampleRate = format.sampleRate.toInt()
            val channelConfig = if (format.channels == 2)
                android.media.AudioFormat.CHANNEL_OUT_STEREO
            else
                android.media.AudioFormat.CHANNEL_OUT_MONO
            val encoding = android.media.AudioFormat.ENCODING_PCM_16BIT

            val minBuf = android.media.AudioTrack.getMinBufferSize(sampleRate, channelConfig, encoding)
            val actualBufSize = maxOf(bufferSize, minBuf)

            audioTrack = android.media.AudioTrack(
                android.media.AudioManager.STREAM_MUSIC,
                sampleRate,
                channelConfig,
                encoding,
                actualBufSize,
                android.media.AudioTrack.MODE_STREAM
            )
        } catch (e: Exception) {
            audioTrack = null
        }
    }

    override fun close() {
        open = false
        try {
            audioTrack?.release()
        } catch (_: Exception) {}
        audioTrack = null
    }

    override fun isOpen(): Boolean = open
    override fun getLineInfo(): Line.Info = DataLine.Info(SourceDataLine::class.java, null)

    override fun write(b: ByteArray?, off: Int, len: Int): Int {
        if (b == null || audioTrack == null) return len
        val fmt = audioFormat

        if (fmt != null && fmt.bigEndian && fmt.sampleSizeInBits == 16) {
            if (swapBuffer == null || swapBuffer!!.size < len) {
                swapBuffer = ByteArray(len)
            }
            val buf = swapBuffer!!
            var i = 0
            while (i < len - 1) {
                buf[i] = b[off + i + 1]
                buf[i + 1] = b[off + i]
                i += 2
            }
            return audioTrack!!.write(buf, 0, len)
        }

        return audioTrack!!.write(b, off, len)
    }

    override fun drain() {
        audioTrack?.flush()
    }

    override fun flush() {
        audioTrack?.flush()
    }

    override fun start() {
        try {
            audioTrack?.play()
        } catch (_: Exception) {}
    }

    override fun stop() {
        try {
            audioTrack?.stop()
        } catch (_: Exception) {}
    }

    override fun getFormat(): AudioFormat = audioFormat ?: AudioFormat(44100f, 16, 2, true, false)
    override fun getBufferSize(): Int = 4096
    override fun available(): Int = 4096
    override fun getFramePosition(): Int = 0
    override fun getLongFramePosition(): Long = 0
    override fun getMicrosecondPosition(): Long = 0
    override fun getLevel(): Float = 0f
}

private class StubTargetDataLine : TargetDataLine {
    private var open = false
    override val isActive: Boolean get() = false
    override val isRunning: Boolean get() = false
    override fun open() { open = true }
    override fun open(format: AudioFormat?) { open = true }
    override fun open(format: AudioFormat?, bufferSize: Int) { open = true }
    override fun close() { open = false }
    override fun isOpen(): Boolean = open
    override fun getLineInfo(): Line.Info = DataLine.Info(TargetDataLine::class.java, null)
    override fun read(b: ByteArray?, off: Int, len: Int): Int = 0
    override fun drain() {}
    override fun flush() {}
    override fun start() {}
    override fun stop() {}
    override fun getFormat(): AudioFormat = AudioFormat(44100f, 16, 2, true, false)
    override fun getBufferSize(): Int = 4096
    override fun available(): Int = 0
    override fun getFramePosition(): Int = 0
    override fun getLongFramePosition(): Long = 0
    override fun getMicrosecondPosition(): Long = 0
    override fun getLevel(): Float = 0f
}

private class StubClip : Clip {
    private var open = false
    private var _framePosition = 0
    override val isActive: Boolean get() = false
    override val isRunning: Boolean get() = false
    override fun open() { open = true }
    override fun open(format: AudioFormat?, data: ByteArray?, offset: Int, bufferSize: Int) { open = true }
    override fun open(stream: AudioInputStream?) { open = true }
    override fun close() { open = false }
    override fun isOpen(): Boolean = open
    override fun getLineInfo(): Line.Info = DataLine.Info(Clip::class.java, null)
    override fun getFrameLength(): Int = 0
    override fun getMicrosecondLength(): Long = 0
    override fun setFramePosition(frames: Int) { _framePosition = frames }
    override fun setMicrosecondPosition(microseconds: Long) {}
    override fun setLoopPoints(start: Int, end: Int) {}
    override fun loop(count: Int) {}
    override fun drain() {}
    override fun flush() {}
    override fun start() {}
    override fun stop() {}
    override fun getFormat(): AudioFormat = AudioFormat(44100f, 16, 2, true, false)
    override fun getBufferSize(): Int = 0
    override fun available(): Int = 0
    override fun getFramePosition(): Int = 0
    override fun getLongFramePosition(): Long = 0
    override fun getMicrosecondPosition(): Long = 0
    override fun getLevel(): Float = 0f
}
