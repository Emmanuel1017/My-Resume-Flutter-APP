@file:Suppress("UNUSED_PARAMETER", "unused")
package javax.sound.midi

import java.io.File
import java.io.InputStream
import java.io.OutputStream

// ============ MidiMessage hierarchy ============

abstract class MidiMessage(@JvmField var data: ByteArray? = null) : Cloneable {
    open val message: ByteArray get() = data ?: ByteArray(0)
    open val length: Int get() = data?.size ?: 0

    open fun getStatus(): Int = data?.firstOrNull()?.toInt()?.and(0xFF) ?: 0
    public abstract override fun clone(): Any
}

open class ShortMessage : MidiMessage {
    constructor() : super(byteArrayOf(0, 0, 0))
    constructor(status: Int) : super(byteArrayOf(status.toByte(), 0, 0))
    constructor(status: Int, data1: Int, data2: Int) : super(byteArrayOf(status.toByte(), data1.toByte(), data2.toByte()))
    constructor(command: Int, channel: Int, data1: Int, data2: Int) : super(byteArrayOf((command or channel).toByte(), data1.toByte(), data2.toByte()))
    open fun setMessage(status: Int) { data = byteArrayOf(status.toByte()) }
    open fun setMessage(status: Int, data1: Int, data2: Int) { data = byteArrayOf(status.toByte(), data1.toByte(), data2.toByte()) }
    open fun setMessage(command: Int, channel: Int, data1: Int, data2: Int) { data = byteArrayOf((command or channel).toByte(), data1.toByte(), data2.toByte()) }
    open fun getChannel(): Int = (data?.firstOrNull()?.toInt() ?: 0) and 0x0F
    open fun getCommand(): Int = (data?.firstOrNull()?.toInt() ?: 0) and 0xF0
    open fun getData1(): Int = data?.getOrNull(1)?.toInt()?.and(0xFF) ?: 0
    open fun getData2(): Int = data?.getOrNull(2)?.toInt()?.and(0xFF) ?: 0
    override fun clone(): Any = ShortMessage(getStatus(), getData1(), getData2())

    companion object {
        const val NOTE_OFF = 0x80
        const val NOTE_ON = 0x90
        const val POLY_PRESSURE = 0xA0
        const val CONTROL_CHANGE = 0xB0
        const val PROGRAM_CHANGE = 0xC0
        const val CHANNEL_PRESSURE = 0xD0
        const val PITCH_BEND = 0xE0
        const val SYSTEM_EXCLUSIVE = 0xF0
        const val MIDI_TIME_CODE = 0xF1
        const val SONG_POSITION_POINTER = 0xF2
        const val SONG_SELECT = 0xF3
        const val TUNE_REQUEST = 0xF6
        const val END_OF_EXCLUSIVE = 0xF7
        const val TIMING_CLOCK = 0xF8
        const val START = 0xFA
        const val CONTINUE = 0xFB
        const val STOP = 0xFC
        const val ACTIVE_SENSING = 0xFE
        const val SYSTEM_RESET = 0xFF
    }
}

open class MetaMessage : MidiMessage {
    constructor() : super(byteArrayOf(0xFF.toByte(), 0, 0))
    constructor(type: Int, msgData: ByteArray?, length: Int) : super(buildMetaBytes(type, msgData, length))

    open fun setMessage(type: Int, msgData: ByteArray?, length: Int) {
        data = buildMetaBytes(type, msgData, length)
    }

    open fun getType(): Int = this.data?.getOrNull(1)?.toInt()?.and(0xFF) ?: 0
    open fun getData(): ByteArray {
        val d = data ?: return ByteArray(0)
        if (d.size < 3) return ByteArray(0)
        // Skip 0xFF, type, then read varlen to find data start
        var idx = 2
        while (idx < d.size && (d[idx].toInt() and 0x80) != 0) idx++
        idx++ // skip final length byte
        return if (idx < d.size) d.copyOfRange(idx, d.size) else ByteArray(0)
    }
    override fun clone(): Any = MetaMessage(getType(), getData(), getData().size)

    companion object {
        const val META = 0xFF

        private fun buildMetaBytes(type: Int, msgData: ByteArray?, length: Int): ByteArray {
            val payload = msgData?.take(length)?.toByteArray() ?: ByteArray(0)
            val lenBytes = encodeVarLen(payload.size.toLong())
            return byteArrayOf(0xFF.toByte(), type.toByte(), *lenBytes, *payload)
        }

        private fun encodeVarLen(value: Long): ByteArray {
            if (value == 0L) return byteArrayOf(0)
            val bytes = mutableListOf<Byte>()
            var v = value
            bytes.add(0, (v and 0x7F).toByte())
            v = v shr 7
            while (v > 0) {
                bytes.add(0, ((v and 0x7F) or 0x80).toByte())
                v = v shr 7
            }
            return bytes.toByteArray()
        }
    }
}

open class SysexMessage : MidiMessage {
    constructor() : super(byteArrayOf(0xF0.toByte()))
    constructor(data: ByteArray?, length: Int) : super(data?.take(length)?.toByteArray())
    constructor(status: Int, data: ByteArray?, length: Int) : super(byteArrayOf(status.toByte(), *data?.take(length)?.toByteArray() ?: ByteArray(0)))
    open fun setMessage(data: ByteArray?, length: Int) { this.data = data?.take(length)?.toByteArray() }
    open fun setMessage(status: Int, data: ByteArray?, length: Int) { this.data = byteArrayOf(status.toByte(), *data?.take(length)?.toByteArray() ?: ByteArray(0)) }
    open fun getData(): ByteArray = data?.drop(1)?.toByteArray() ?: ByteArray(0)
    override fun clone(): Any = SysexMessage(data, data?.size ?: 0)

    companion object {
        const val SYSTEM_EXCLUSIVE = 0xF0
        const val SPECIAL_SYSTEM_EXCLUSIVE = 0xF7
    }
}

// ============ MidiEvent ============

open class MidiEvent(@JvmField val message: MidiMessage?, @JvmField var tick: Long = 0) {
}

// ============ Track ============

open class Track {
    private val events = mutableListOf<MidiEvent>()

    open fun add(event: MidiEvent?): Boolean { event?.let { events.add(it) }; return true }
    open fun remove(event: MidiEvent?): Boolean = events.remove(event)
    open fun get(index: Int): MidiEvent? = events.getOrNull(index)
    open fun size(): Int = events.size
    open fun ticks(): Long = events.maxOfOrNull { it.tick } ?: 0
}

// ============ Sequence ============

open class Sequence {
    val divisionType: Float
    val resolution: Int
    val tracks: MutableList<Track> = mutableListOf()

    constructor(divisionType: Float, resolution: Int) {
        this.divisionType = divisionType
        this.resolution = resolution
    }

    constructor(divisionType: Float, resolution: Int, numTracks: Int) {
        this.divisionType = divisionType
        this.resolution = resolution
        repeat(numTracks) { tracks.add(Track()) }
    }

    open fun createTrack(): Track { val t = Track(); tracks.add(t); return t }
    open fun deleteTrack(track: Track?): Boolean = tracks.remove(track)
    open fun getMicrosecondLength(): Long = 0
    open fun getTickLength(): Long = tracks.maxOfOrNull { it.ticks() } ?: 0
    open fun getPatchList(): Array<Patch> = emptyArray()

    companion object {
        const val PPQ = 0.0f
        const val SMPTE_24 = 24.0f
        const val SMPTE_25 = 25.0f
        const val SMPTE_30DROP = 29.97f
        const val SMPTE_30 = 30.0f
    }
}

// ============ Patch ============

open class Patch(val bank: Int = 0, val program: Int = 0) {
}

// ============ Instrument / Soundbank ============

abstract class Instrument(val soundbank: Soundbank?, val patch: Patch?, val name: String?) {
}

interface Soundbank {
    fun getResources(): Array<SoundbankResource>
    fun getInstruments(): Array<Instrument>
    fun getInstrument(patch: Patch?): Instrument?
}

abstract class SoundbankResource(val soundbank: Soundbank?, val name: String?, val dataClass: Class<*>?) {
    abstract fun getData(): Any?
}

// ============ MidiDevice / Synthesizer / Sequencer ============

interface MidiDevice : AutoCloseable {
    fun getDeviceInfo(): Info
    fun open()
    override fun close()
    fun isOpen(): Boolean
    fun getMicrosecondPosition(): Long
    fun getMaxReceivers(): Int
    fun getMaxTransmitters(): Int
    fun getReceiver(): Receiver
    fun getReceivers(): List<Receiver>
    fun getTransmitter(): Transmitter
    fun getTransmitters(): List<Transmitter>

    open class Info(val name: String, val vendor: String, val description: String, val version: String) {
        override fun toString(): String = name
    }
}

// Extension properties for Java bean-style access
val MidiDevice.receiver: Receiver get() = getReceiver()
val MidiDevice.transmitter: Transmitter get() = getTransmitter()
val MidiDevice.maxReceivers: Int get() = getMaxReceivers()
val MidiDevice.maxTransmitters: Int get() = getMaxTransmitters()

interface Synthesizer : MidiDevice {
    fun getMaxPolyphony(): Int
    fun getLatency(): Long
    fun getChannels(): Array<MidiChannel>
    fun getVoiceStatus(): Array<VoiceStatus>
    fun isSoundbankSupported(soundbank: Soundbank?): Boolean
    fun loadInstrument(instrument: Instrument?): Boolean
    fun unloadInstrument(instrument: Instrument?)
    fun remapInstrument(from: Instrument?, to: Instrument?): Boolean
    fun getDefaultSoundbank(): Soundbank?
    fun getAvailableInstruments(): Array<Instrument>
    fun getLoadedInstruments(): Array<Instrument>
    fun loadAllInstruments(soundbank: Soundbank?): Boolean
    fun unloadAllInstruments(soundbank: Soundbank?)
    fun loadInstruments(soundbank: Soundbank?, patchList: Array<Patch>?): Boolean
    fun unloadInstruments(soundbank: Soundbank?, patchList: Array<Patch>?)
}

val Synthesizer.defaultSoundbank: Soundbank? get() = getDefaultSoundbank()

interface Sequencer : MidiDevice {
    fun setSequence(sequence: Sequence?)
    fun setSequence(stream: InputStream?)
    fun getSequence(): Sequence?
    fun start()
    fun stop()
    fun isRunning(): Boolean
    fun startRecording()
    fun stopRecording()
    fun isRecording(): Boolean
    fun recordEnable(track: Track?, channel: Int)
    fun recordDisable(track: Track?)
    fun getTempoInBPM(): Float
    fun setTempoInBPM(bpm: Float)
    fun getTempoInMPQ(): Float
    fun setTempoInMPQ(mpq: Float)
    fun setTempoFactor(factor: Float)
    fun getTempoFactor(): Float
    fun getTickLength(): Long
    fun getTickPosition(): Long
    fun setTickPosition(tick: Long)
    fun getMicrosecondLength(): Long
    override fun getMicrosecondPosition(): Long
    fun setMicrosecondPosition(microseconds: Long)
    fun setMasterSyncMode(sync: SyncMode?)
    fun getMasterSyncMode(): SyncMode
    fun getMasterSyncModes(): Array<SyncMode>
    fun setSlaveSyncMode(sync: SyncMode?)
    fun getSlaveSyncMode(): SyncMode
    fun getSlaveSyncModes(): Array<SyncMode>
    fun setTrackMute(track: Int, mute: Boolean)
    fun getTrackMute(track: Int): Boolean
    fun setTrackSolo(track: Int, solo: Boolean)
    fun getTrackSolo(track: Int): Boolean
    fun addMetaEventListener(listener: MetaEventListener?): Boolean
    fun removeMetaEventListener(listener: MetaEventListener?)
    fun addControllerEventListener(listener: ControllerEventListener?, controllers: IntArray?): IntArray
    fun removeControllerEventListener(listener: ControllerEventListener?, controllers: IntArray?): IntArray
    fun setLoopStartPoint(tick: Long)
    fun getLoopStartPoint(): Long
    fun setLoopEndPoint(tick: Long)
    fun getLoopEndPoint(): Long
    fun setLoopCount(count: Int)
    fun getLoopCount(): Int

    open class SyncMode(val name: String?) {
        companion object {
            @JvmField val INTERNAL_CLOCK = SyncMode("Internal Clock")
            @JvmField val MIDI_SYNC = SyncMode("MIDI Sync")
            @JvmField val MIDI_TIME_CODE = SyncMode("MIDI Time Code")
            @JvmField val NO_SYNC = SyncMode("No Timing")
        }
        override fun toString(): String = name ?: ""
    }

    companion object {
        const val LOOP_CONTINUOUSLY = -1
    }
}

var Sequencer.sequence: Sequence?
    get() = getSequence()
    set(value) { setSequence(value) }
var Sequencer.loopCount: Int
    get() = getLoopCount()
    set(value) { setLoopCount(value) }

// ============ Receiver / Transmitter ============

interface Receiver : AutoCloseable {
    fun send(message: MidiMessage, timeStamp: Long)
    override fun close()
}

interface Transmitter : AutoCloseable {
    fun setReceiver(receiver: Receiver)
    fun getReceiver(): Receiver?
    override fun close()
}

// ============ MidiChannel ============

interface MidiChannel {
    fun noteOn(noteNumber: Int, velocity: Int)
    fun noteOff(noteNumber: Int, velocity: Int)
    fun noteOff(noteNumber: Int)
    fun setPolyPressure(noteNumber: Int, pressure: Int)
    fun getPolyPressure(noteNumber: Int): Int
    fun setChannelPressure(pressure: Int)
    fun getChannelPressure(): Int
    fun controlChange(controller: Int, value: Int)
    fun getController(controller: Int): Int
    fun programChange(program: Int)
    fun programChange(bank: Int, program: Int)
    fun setPitchBend(bend: Int)
    fun getPitchBend(): Int
    fun resetAllControllers()
    fun allNotesOff()
    fun allSoundOff()
    fun localControl(on: Boolean): Boolean
    fun setMono(on: Boolean)
    fun getMono(): Boolean
    fun setOmni(on: Boolean)
    fun getOmni(): Boolean
    fun setMute(mute: Boolean)
    fun getMute(): Boolean
    fun setSolo(soloState: Boolean)
    fun getSolo(): Boolean
}

// ============ VoiceStatus ============

open class VoiceStatus {
    var active: Boolean = false
    var channel: Int = 0
    var bank: Int = 0
    var program: Int = 0
    var note: Int = 0
    var volume: Int = 0
}

// ============ Listeners ============

interface MetaEventListener {
    fun meta(meta: MetaMessage?)
}

interface ControllerEventListener {
    fun controlChange(event: ShortMessage?)
}

// ============ MidiSystem ============

object MidiSystem {
    @JvmField
    var androidCacheDir: java.io.File? = null

    private val activeSequencers = mutableListOf<StubSequencer>()

    @JvmStatic
    fun stopAll() {
        synchronized(activeSequencers) {
            for (seq in activeSequencers) {
                seq.close()
            }
            activeSequencers.clear()
        }
    }

    @JvmStatic
    fun getSequencer(): Sequencer {
        val seq = StubSequencer()
        synchronized(activeSequencers) { activeSequencers.add(seq) }
        return seq
    }

    @JvmStatic
    fun getSequencer(connected: Boolean): Sequencer {
        val seq = StubSequencer()
        synchronized(activeSequencers) { activeSequencers.add(seq) }
        return seq
    }

    @JvmStatic
    fun getSynthesizer(): Synthesizer = StubSynthesizer()

    @JvmStatic
    fun getReceiver(): Receiver = StubReceiver()

    @JvmStatic
    fun getTransmitter(): Transmitter = StubTransmitter()

    @JvmStatic
    fun getMidiDeviceInfo(): Array<MidiDevice.Info> = arrayOf(
        MidiDevice.Info("Android Stub", "Stub", "No-op MIDI device", "1.0")
    )

    @JvmStatic
    fun getMidiDevice(info: MidiDevice.Info?): MidiDevice = StubMidiDevice()

    @JvmStatic
    fun getSequence(stream: InputStream?): Sequence? = throw InvalidMidiDataException("Not a MIDI file")

    @JvmStatic
    fun getSequence(file: File?): Sequence? = throw InvalidMidiDataException("Not a MIDI file")

    @JvmStatic
    fun getSequence(url: java.net.URL?): Sequence? = throw InvalidMidiDataException("Not a MIDI file")

    @JvmStatic
    fun getMidiFileFormat(stream: InputStream?): MidiFileFormat = MidiFileFormat()

    @JvmStatic
    fun getMidiFileFormat(file: File?): MidiFileFormat = MidiFileFormat()

    @JvmStatic
    fun isFileTypeSupported(fileType: Int): Boolean = false

    @JvmStatic
    fun isFileTypeSupported(fileType: Int, sequence: Sequence?): Boolean = false

    @JvmStatic
    fun getMidiFileTypes(): IntArray = IntArray(0)

    @JvmStatic
    fun getMidiFileTypes(sequence: Sequence?): IntArray = IntArray(0)

    @JvmStatic
    fun write(sequence: Sequence?, fileType: Int, out: OutputStream?): Int = 0

    @JvmStatic
    fun write(sequence: Sequence?, fileType: Int, out: File?): Int = 0

    @JvmStatic
    fun getSoundbank(stream: InputStream?): Soundbank? = null

    @JvmStatic
    fun getSoundbank(file: File?): Soundbank? = null

    @JvmStatic
    fun getSoundbank(url: java.net.URL?): Soundbank? = null
}

// ============ MidiFileFormat ============

open class MidiFileFormat {
    open fun getType(): Int = 0
    open fun getByteLength(): Int = -1
    open fun getMicrosecondLength(): Long = -1
}

// ============ Exceptions ============

open class MidiUnavailableException(message: String? = null) : Exception(message)
open class InvalidMidiDataException(message: String? = null) : Exception(message)

// ============ Stub MidiDevice implementation ============

private class StubReceiver : Receiver {
    override fun send(message: MidiMessage, timeStamp: Long) {}
    override fun close() {}
}

private class StubTransmitter : Transmitter {
    private var _receiver: Receiver? = null
    override fun setReceiver(receiver: Receiver) { _receiver = receiver }
    override fun getReceiver(): Receiver? = _receiver
    override fun close() {}
}

private class StubMidiDevice : MidiDevice {
    private var open = false
    override fun getDeviceInfo(): MidiDevice.Info = MidiDevice.Info("Stub", "Stub", "Stub MIDI Device", "1.0")
    override fun open() { open = true }
    override fun close() { open = false }
    override fun isOpen(): Boolean = open
    override fun getMicrosecondPosition(): Long = 0
    override fun getMaxReceivers(): Int = -1
    override fun getMaxTransmitters(): Int = -1
    override fun getReceiver(): Receiver = StubReceiver()
    override fun getReceivers(): List<Receiver> = emptyList()
    override fun getTransmitter(): Transmitter = StubTransmitter()
    override fun getTransmitters(): List<Transmitter> = emptyList()
}

private class StubSequencer : Sequencer {
    private var open = false
    private var _sequence: Sequence? = null
    private var _running = false
    private var _tickPos: Long = 0
    private var _microPos: Long = 0
    private var _tempo: Float = 120f
    private var _tempoFactor: Float = 1f
    private var _loopCount: Int = 0
    private var mediaPlayer: android.media.MediaPlayer? = null
    private var midiFile: java.io.File? = null

    override fun getDeviceInfo(): MidiDevice.Info = MidiDevice.Info("StubSeq", "Stub", "Stub Sequencer", "1.0")
    override fun open() { open = true }
    override fun close() {
        open = false
        _running = false
        mediaPlayer?.release()
        mediaPlayer = null
        midiFile?.delete()
        midiFile = null
    }
    override fun isOpen(): Boolean = open
    override fun getMicrosecondPosition(): Long = _microPos
    override fun getMaxReceivers(): Int = -1
    override fun getMaxTransmitters(): Int = -1
    override fun getReceiver(): Receiver = StubReceiver()
    override fun getReceivers(): List<Receiver> = emptyList()
    override fun getTransmitter(): Transmitter = StubTransmitter()
    override fun getTransmitters(): List<Transmitter> = emptyList()

    override fun setSequence(sequence: Sequence?) { _sequence = sequence }
    override fun setSequence(stream: java.io.InputStream?) {}
    override fun getSequence(): Sequence? = _sequence

    override fun start() {
        _running = true
        val seq = _sequence ?: return
        Thread({
            try {
                mediaPlayer?.release()
                mediaPlayer = null
                val midiBytes = sequenceToMidiBytes(seq)
                val tmpDir = MidiSystem.androidCacheDir ?: java.io.File(System.getProperty("java.io.tmpdir") ?: "/data/local/tmp")
                if (!tmpDir.exists()) tmpDir.mkdirs()
                val file = java.io.File(tmpDir, "doom_music.mid")
                file.writeBytes(midiBytes)
                midiFile = file

                val mp = android.media.MediaPlayer()
                mp.setDataSource(file.absolutePath)
                mp.setAudioAttributes(
                    android.media.AudioAttributes.Builder()
                        .setContentType(android.media.AudioAttributes.CONTENT_TYPE_MUSIC)
                        .setUsage(android.media.AudioAttributes.USAGE_GAME)
                        .build()
                )
                mp.isLooping = _loopCount == Sequencer.LOOP_CONTINUOUSLY
                mp.prepare()
                mp.start()
                mediaPlayer = mp
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }, "midi-loader").start()
    }

    override fun stop() {
        _running = false
        try {
            mediaPlayer?.stop()
        } catch (_: Exception) {}
    }

    override fun isRunning(): Boolean = _running
    override fun startRecording() {}
    override fun stopRecording() {}
    override fun isRecording(): Boolean = false
    override fun recordEnable(track: Track?, channel: Int) {}
    override fun recordDisable(track: Track?) {}
    override fun getTempoInBPM(): Float = _tempo
    override fun setTempoInBPM(bpm: Float) { _tempo = bpm }
    override fun getTempoInMPQ(): Float = 60000000f / _tempo
    override fun setTempoInMPQ(mpq: Float) { _tempo = 60000000f / mpq }
    override fun setTempoFactor(factor: Float) { _tempoFactor = factor }
    override fun getTempoFactor(): Float = _tempoFactor
    override fun getTickLength(): Long = _sequence?.getTickLength() ?: 0
    override fun getTickPosition(): Long = _tickPos
    override fun setTickPosition(tick: Long) { _tickPos = tick }
    override fun getMicrosecondLength(): Long = 0
    override fun setMicrosecondPosition(microseconds: Long) { _microPos = microseconds }
    override fun setMasterSyncMode(sync: Sequencer.SyncMode?) {}
    override fun getMasterSyncMode(): Sequencer.SyncMode = Sequencer.SyncMode.INTERNAL_CLOCK
    override fun getMasterSyncModes(): Array<Sequencer.SyncMode> = arrayOf(Sequencer.SyncMode.INTERNAL_CLOCK)
    override fun setSlaveSyncMode(sync: Sequencer.SyncMode?) {}
    override fun getSlaveSyncMode(): Sequencer.SyncMode = Sequencer.SyncMode.INTERNAL_CLOCK
    override fun getSlaveSyncModes(): Array<Sequencer.SyncMode> = arrayOf(Sequencer.SyncMode.INTERNAL_CLOCK)
    override fun setTrackMute(track: Int, mute: Boolean) {}
    override fun getTrackMute(track: Int): Boolean = false
    override fun setTrackSolo(track: Int, solo: Boolean) {}
    override fun getTrackSolo(track: Int): Boolean = false
    override fun addMetaEventListener(listener: MetaEventListener?): Boolean = true
    override fun removeMetaEventListener(listener: MetaEventListener?) {}
    override fun addControllerEventListener(listener: ControllerEventListener?, controllers: IntArray?): IntArray = controllers ?: intArrayOf()
    override fun removeControllerEventListener(listener: ControllerEventListener?, controllers: IntArray?): IntArray = controllers ?: intArrayOf()
    override fun setLoopStartPoint(tick: Long) {}
    override fun getLoopStartPoint(): Long = 0
    override fun setLoopEndPoint(tick: Long) {}
    override fun getLoopEndPoint(): Long = -1
    override fun setLoopCount(count: Int) { _loopCount = count }
    override fun getLoopCount(): Int = _loopCount

    private fun sequenceToMidiBytes(seq: Sequence): ByteArray {
        val out = java.io.ByteArrayOutputStream()

        // Determine division type
        val division: Int = if (seq.divisionType == Sequence.PPQ) {
            seq.resolution and 0x7FFF
        } else {
            // SMPTE: encode as negative frames-per-second + ticks-per-frame
            val fps = seq.divisionType.toInt()
            ((256 - fps) shl 8) or (seq.resolution and 0xFF)
        }

        // Merge all tracks into one for Format 0
        val allEvents = mutableListOf<MidiEvent>()
        for (track in seq.tracks) {
            for (i in 0 until track.size()) {
                track.get(i)?.let { allEvents.add(it) }
            }
        }
        allEvents.sortBy { it.tick }

        val trackData = java.io.ByteArrayOutputStream()
        var lastTick: Long = 0
        for (event in allEvents) {
            val delta = event.tick - lastTick
            lastTick = event.tick
            writeVarLen(trackData, delta)
            val msg = event.message ?: continue
            val bytes = msg.message
            if (bytes.isNotEmpty()) {
                trackData.write(bytes)
            }
        }

        // MThd header
        out.write("MThd".toByteArray())
        writeInt(out, 6)           // header length
        writeShort(out, 0)         // format 0
        writeShort(out, 1)         // 1 track
        writeShort(out, division)  // division

        // MTrk
        out.write("MTrk".toByteArray())
        writeInt(out, trackData.size())
        out.write(trackData.toByteArray())

        return out.toByteArray()
    }

    private fun writeVarLen(out: java.io.ByteArrayOutputStream, value: Long) {
        var v = value
        var buf = (v and 0x7F).toInt()
        v = v shr 7
        while (v > 0) {
            buf = buf shl 8
            buf = buf or ((v and 0x7F).toInt() or 0x80)
            v = v shr 7
        }
        while (true) {
            out.write(buf and 0xFF)
            if (buf and 0x80 != 0) {
                buf = buf shr 8
            } else {
                break
            }
        }
    }

    private fun writeInt(out: java.io.OutputStream, v: Int) {
        out.write((v shr 24) and 0xFF)
        out.write((v shr 16) and 0xFF)
        out.write((v shr 8) and 0xFF)
        out.write(v and 0xFF)
    }

    private fun writeShort(out: java.io.OutputStream, v: Int) {
        out.write((v shr 8) and 0xFF)
        out.write(v and 0xFF)
    }
}

private class StubSynthesizer : Synthesizer {
    private var open = false
    override fun getDeviceInfo(): MidiDevice.Info = MidiDevice.Info("StubSynth", "Stub", "Stub Synthesizer", "1.0")
    override fun open() { open = true }
    override fun close() { open = false }
    override fun isOpen(): Boolean = open
    override fun getMicrosecondPosition(): Long = 0
    override fun getMaxReceivers(): Int = -1
    override fun getMaxTransmitters(): Int = -1
    override fun getReceiver(): Receiver = StubReceiver()
    override fun getReceivers(): List<Receiver> = emptyList()
    override fun getTransmitter(): Transmitter = StubTransmitter()
    override fun getTransmitters(): List<Transmitter> = emptyList()

    override fun getMaxPolyphony(): Int = 64
    override fun getLatency(): Long = 0
    override fun getChannels(): Array<MidiChannel> = Array(16) { object : MidiChannel {
        override fun noteOn(noteNumber: Int, velocity: Int) {}
        override fun noteOff(noteNumber: Int, velocity: Int) {}
        override fun noteOff(noteNumber: Int) {}
        override fun setPolyPressure(noteNumber: Int, pressure: Int) {}
        override fun getPolyPressure(noteNumber: Int): Int = 0
        override fun setChannelPressure(pressure: Int) {}
        override fun getChannelPressure(): Int = 0
        override fun controlChange(controller: Int, value: Int) {}
        override fun getController(controller: Int): Int = 0
        override fun programChange(program: Int) {}
        override fun programChange(bank: Int, program: Int) {}
        override fun setPitchBend(bend: Int) {}
        override fun getPitchBend(): Int = 8192
        override fun resetAllControllers() {}
        override fun allNotesOff() {}
        override fun allSoundOff() {}
        override fun localControl(on: Boolean): Boolean = false
        override fun setMono(on: Boolean) {}
        override fun getMono(): Boolean = false
        override fun setOmni(on: Boolean) {}
        override fun getOmni(): Boolean = false
        override fun setMute(mute: Boolean) {}
        override fun getMute(): Boolean = false
        override fun setSolo(soloState: Boolean) {}
        override fun getSolo(): Boolean = false
    }}
    override fun getVoiceStatus(): Array<VoiceStatus> = emptyArray()
    override fun isSoundbankSupported(soundbank: Soundbank?): Boolean = false
    override fun loadInstrument(instrument: Instrument?): Boolean = false
    override fun unloadInstrument(instrument: Instrument?) {}
    override fun remapInstrument(from: Instrument?, to: Instrument?): Boolean = false
    override fun getDefaultSoundbank(): Soundbank? = null
    override fun getAvailableInstruments(): Array<Instrument> = emptyArray()
    override fun getLoadedInstruments(): Array<Instrument> = emptyArray()
    override fun loadAllInstruments(soundbank: Soundbank?): Boolean = false
    override fun unloadAllInstruments(soundbank: Soundbank?) {}
    override fun loadInstruments(soundbank: Soundbank?, patchList: Array<Patch>?): Boolean = false
    override fun unloadInstruments(soundbank: Soundbank?, patchList: Array<Patch>?) {}
}
