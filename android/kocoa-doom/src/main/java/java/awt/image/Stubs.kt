@file:Suppress("UNUSED_PARAMETER", "unused")
package java.awt.image

import java.awt.*

// ============ ImageObserver ============

interface ImageObserver {
    fun imageUpdate(img: Image?, infoflags: Int, x: Int, y: Int, width: Int, height: Int): Boolean

    companion object {
        const val WIDTH = 1
        const val HEIGHT = 2
        const val PROPERTIES = 4
        const val SOMEBITS = 8
        const val FRAMEBITS = 16
        const val ALLBITS = 32
        const val ERROR = 64
        const val ABORT = 128
    }
}

// ============ DataBuffer hierarchy ============

abstract class DataBuffer(val dataType: Int, val size: Int, val numBanks: Int = 1) {
    open fun getElem(i: Int): Int = 0
    open fun getElem(bank: Int, i: Int): Int = 0
    open fun setElem(i: Int, value: Int) {}
    open fun setElem(bank: Int, i: Int, value: Int) {}

    companion object {
        const val TYPE_BYTE = 0
        const val TYPE_USHORT = 1
        const val TYPE_SHORT = 2
        const val TYPE_INT = 3
        const val TYPE_FLOAT = 4
        const val TYPE_DOUBLE = 5
        const val TYPE_UNDEFINED = 32
    }
}

open class DataBufferByte : DataBuffer {
    val data: ByteArray

    constructor(size: Int) : super(TYPE_BYTE, size) {
        data = ByteArray(size)
    }

    constructor(data: ByteArray?, size: Int) : super(TYPE_BYTE, size) {
        this.data = data ?: ByteArray(size)
    }

    constructor(dataArrays: Array<ByteArray>, size: Int) : super(TYPE_BYTE, size, dataArrays.size) {
        this.data = if (dataArrays.isNotEmpty()) dataArrays[0] else ByteArray(size)
    }


    override fun getElem(i: Int): Int = data[i].toInt() and 0xFF
    override fun setElem(i: Int, value: Int) { data[i] = value.toByte() }
}

open class DataBufferInt : DataBuffer {
    val data: IntArray

    constructor(size: Int) : super(TYPE_INT, size) {
        data = IntArray(size)
    }

    constructor(data: IntArray?, size: Int) : super(TYPE_INT, size) {
        this.data = data ?: IntArray(size)
    }

    constructor(dataArrays: Array<IntArray>, size: Int) : super(TYPE_INT, size, dataArrays.size) {
        this.data = if (dataArrays.isNotEmpty()) dataArrays[0] else IntArray(size)
    }


    override fun getElem(i: Int): Int = data[i]
    override fun setElem(i: Int, value: Int) { data[i] = value }
}

open class DataBufferUShort : DataBuffer {
    val data: ShortArray

    constructor(size: Int) : super(TYPE_USHORT, size) {
        data = ShortArray(size)
    }

    constructor(data: ShortArray?, size: Int) : super(TYPE_USHORT, size) {
        this.data = data ?: ShortArray(size)
    }


    override fun getElem(i: Int): Int = data[i].toInt() and 0xFFFF
    override fun setElem(i: Int, value: Int) { data[i] = value.toShort() }
}

// ============ SampleModel ============

open class SampleModel(val dataType: Int, val width: Int, val height: Int, val numBands: Int) {
    open fun getDataElements(x: Int, y: Int, obj: Any?, data: DataBuffer?): Any? = obj
    open fun setDataElements(x: Int, y: Int, obj: Any?, data: DataBuffer?) {}
    open fun getSample(x: Int, y: Int, b: Int, data: DataBuffer?): Int = 0
    open fun setSample(x: Int, y: Int, b: Int, s: Int, data: DataBuffer?) {}
    open fun getPixel(x: Int, y: Int, iArray: IntArray?, data: DataBuffer?): IntArray = iArray ?: IntArray(numBands)
    open fun setPixel(x: Int, y: Int, iArray: IntArray?, data: DataBuffer?) {}
    open fun createCompatibleSampleModel(w: Int, h: Int): SampleModel = SampleModel(dataType, w, h, numBands)
    open fun createDataBuffer(): DataBuffer = DataBufferInt(width * height)
}

open class SinglePixelPackedSampleModel(
    dataType: Int, width: Int, height: Int,
    val scanlineStride: Int,
    val bitMasks: IntArray
) : SampleModel(dataType, width, height, bitMasks.size) {
    constructor(dataType: Int, w: Int, h: Int, bitMasks: IntArray) : this(dataType, w, h, w, bitMasks)
}

open class ComponentSampleModel(
    dataType: Int, width: Int, height: Int,
    val pixelStride: Int,
    val scanlineStride: Int,
    val bandOffsets: IntArray
) : SampleModel(dataType, width, height, bandOffsets.size)

open class MultiPixelPackedSampleModel(
    dataType: Int, width: Int, height: Int,
    val numberOfBits: Int
) : SampleModel(dataType, width, height, 1)

// ============ ColorModel ============

open class ColorModel(val pixelSize: Int) {
    open val numComponents: Int get() = 4
    open val numColorComponents: Int get() = 3

    open fun getRed(pixel: Int): Int = (pixel shr 16) and 0xFF
    open fun getGreen(pixel: Int): Int = (pixel shr 8) and 0xFF
    open fun getBlue(pixel: Int): Int = pixel and 0xFF
    open fun getAlpha(pixel: Int): Int = (pixel shr 24) and 0xFF
    open fun getRGB(pixel: Int): Int = pixel
    open fun hasAlpha(): Boolean = true
    open fun isAlphaPremultiplied(): Boolean = false
    open fun getTransferType(): Int = DataBuffer.TYPE_INT
    open fun getTransparency(): Int = Transparency.TRANSLUCENT
    open fun createCompatibleSampleModel(w: Int, h: Int): SampleModel = SampleModel(DataBuffer.TYPE_INT, w, h, 4)
    open fun isCompatibleRaster(raster: Raster?): Boolean = true
    open fun createCompatibleWritableRaster(w: Int, h: Int): WritableRaster = WritableRaster(w, h, DataBufferInt(w * h))
    open fun getComponentSize(): IntArray = intArrayOf(8, 8, 8, 8)
    open fun getComponentSize(componentIdx: Int): Int = getComponentSize().getOrElse(componentIdx) { 8 }

    companion object {
        @JvmStatic
        fun getRGBdefault(): ColorModel = DirectColorModel(32, 0x00FF0000, 0x0000FF00, 0x000000FF, -0x01000000)
    }
}

open class DirectColorModel(
    bits: Int,
    val rmask: Int = 0x00FF0000,
    val gmask: Int = 0x0000FF00,
    val bmask: Int = 0x000000FF,
    val amask: Int = 0xFF000000.toInt()
) : ColorModel(bits) {
    constructor(bits: Int, rmask: Int, gmask: Int, bmask: Int) : this(bits, rmask, gmask, bmask, 0)
}

open class IndexColorModel : ColorModel {
    val rgbs: IntArray
    val mapSize: Int
    val transparentPixel: Int

    constructor(bits: Int, size: Int, r: ByteArray, g: ByteArray, b: ByteArray) : super(bits) {
        mapSize = size
        transparentPixel = -1
        rgbs = IntArray(size) { i ->
            (0xFF shl 24) or
            ((r[i].toInt() and 0xFF) shl 16) or
            ((g[i].toInt() and 0xFF) shl 8) or
            (b[i].toInt() and 0xFF)
        }
    }

    constructor(bits: Int, size: Int, r: ByteArray, g: ByteArray, b: ByteArray, trans: Int) : super(bits) {
        mapSize = size
        transparentPixel = trans
        rgbs = IntArray(size) { i ->
            (if (i == trans) 0 else (0xFF shl 24)) or
            ((r[i].toInt() and 0xFF) shl 16) or
            ((g[i].toInt() and 0xFF) shl 8) or
            (b[i].toInt() and 0xFF)
        }
    }

    constructor(bits: Int, size: Int, r: ByteArray, g: ByteArray, b: ByteArray, a: ByteArray) : super(bits) {
        mapSize = size
        transparentPixel = -1
        rgbs = IntArray(size) { i ->
            ((a[i].toInt() and 0xFF) shl 24) or
            ((r[i].toInt() and 0xFF) shl 16) or
            ((g[i].toInt() and 0xFF) shl 8) or
            (b[i].toInt() and 0xFF)
        }
    }

    constructor(bits: Int, size: Int, cmap: IntArray, start: Int, hasAlpha: Boolean) : super(bits) {
        mapSize = size
        transparentPixel = -1
        rgbs = IntArray(size) { i ->
            if (hasAlpha) cmap[start + i]
            else (0xFF shl 24) or (cmap[start + i] and 0x00FFFFFF)
        }
    }

    constructor(bits: Int, size: Int, cmap: ByteArray?, start: Int, hasAlpha: Boolean) : super(bits) {
        mapSize = size
        transparentPixel = -1
        val cm = cmap ?: ByteArray(0)
        rgbs = IntArray(size) { i ->
            val offset = start + i * 3
            val r = cm.getOrElse(offset) { 0 }.toInt() and 0xFF
            val g = cm.getOrElse(offset + 1) { 0 }.toInt() and 0xFF
            val b = cm.getOrElse(offset + 2) { 0 }.toInt() and 0xFF
            (0xFF shl 24) or (r shl 16) or (g shl 8) or b
        }
    }

    constructor(bits: Int, size: Int, cmap: IntArray, start: Int, hasAlpha: Boolean, trans: Int) : super(bits) {
        mapSize = size
        transparentPixel = trans
        rgbs = IntArray(size) { i ->
            if (i == trans) 0
            else if (hasAlpha) cmap[start + i]
            else (0xFF shl 24) or (cmap[start + i] and 0x00FFFFFF)
        }
    }
    fun getRGBs(rgb: IntArray) { rgbs.copyInto(rgb, 0, 0, minOf(rgbs.size, rgb.size)) }
    fun getReds(r: ByteArray) { for (i in r.indices.take(mapSize)) r[i] = ((rgbs[i] shr 16) and 0xFF).toByte() }
    fun getGreens(g: ByteArray) { for (i in g.indices.take(mapSize)) g[i] = ((rgbs[i] shr 8) and 0xFF).toByte() }
    fun getBlues(b: ByteArray) { for (i in b.indices.take(mapSize)) b[i] = (rgbs[i] and 0xFF).toByte() }
    fun getAlphas(a: ByteArray) { for (i in a.indices.take(mapSize)) a[i] = ((rgbs[i] shr 24) and 0xFF).toByte() }

    override fun getRGB(pixel: Int): Int = if (pixel in rgbs.indices) rgbs[pixel] else 0
    override fun getRed(pixel: Int): Int = (getRGB(pixel) shr 16) and 0xFF
    override fun getGreen(pixel: Int): Int = (getRGB(pixel) shr 8) and 0xFF
    override fun getBlue(pixel: Int): Int = getRGB(pixel) and 0xFF
    override fun getAlpha(pixel: Int): Int = (getRGB(pixel) shr 24) and 0xFF
}

// ============ Raster / WritableRaster ============

open class Raster(
    val width: Int,
    val height: Int,
    val dataBuffer: DataBuffer
) {
    open val sampleModel: SampleModel = SampleModel(dataBuffer.dataType, width, height, 4)
    open fun getMinX(): Int = 0
    open fun getMinY(): Int = 0
    open fun getSample(x: Int, y: Int, b: Int): Int = 0
    open fun getPixel(x: Int, y: Int, iArray: IntArray?): IntArray = iArray ?: IntArray(4)
    open fun getDataElements(x: Int, y: Int, obj: Any?): Any? = obj

    companion object {
        @JvmStatic
        fun createInterleavedRaster(
            dataType: Int, w: Int, h: Int, bands: Int, location: Point?
        ): WritableRaster = WritableRaster(w, h, DataBufferByte(w * h * bands))

        @JvmStatic
        fun createInterleavedRaster(
            dataBuffer: DataBuffer, w: Int, h: Int, scanlineStride: Int, pixelStride: Int,
            bandOffsets: IntArray, location: Point?
        ): WritableRaster = WritableRaster(w, h, dataBuffer)

        @JvmStatic
        fun createPackedRaster(
            dataType: Int, w: Int, h: Int, bands: Int, bitsPerBand: Int, location: Point?
        ): WritableRaster = WritableRaster(w, h, DataBufferInt(w * h))

        @JvmStatic
        fun createPackedRaster(
            dataBuffer: DataBuffer, w: Int, h: Int, bitsPerPixel: Int, location: Point?
        ): WritableRaster = WritableRaster(w, h, dataBuffer)

        @JvmStatic
        fun createPackedRaster(
            dataBuffer: DataBuffer, w: Int, h: Int, scanlineStride: Int, bandMasks: IntArray, location: Point?
        ): WritableRaster = WritableRaster(w, h, dataBuffer)

        @JvmStatic
        fun createWritableRaster(
            sm: SampleModel, db: DataBuffer, location: Point?
        ): WritableRaster = WritableRaster(sm.width, sm.height, db)

        @JvmStatic
        fun createWritableRaster(
            sm: SampleModel, location: Point?
        ): WritableRaster = WritableRaster(sm.width, sm.height, DataBufferInt(sm.width * sm.height))
    }
}

open class WritableRaster(
    width: Int,
    height: Int,
    dataBuffer: DataBuffer
) : Raster(width, height, dataBuffer) {

    open fun setDataElements(x: Int, y: Int, obj: Any?) {}
    open fun setDataElements(x: Int, y: Int, w: Int, h: Int, obj: Any?) {}
    open fun setSample(x: Int, y: Int, b: Int, s: Int) {}
    open fun setPixel(x: Int, y: Int, iArray: IntArray?) {}
    open fun setRect(srcRaster: Raster?) {}
    open fun createWritableChild(
        parentX: Int, parentY: Int, w: Int, h: Int,
        childMinX: Int, childMinY: Int, bandList: IntArray?
    ): WritableRaster = WritableRaster(w, h, dataBuffer)
}

// ============ BufferedImage ============

open class BufferedImage private constructor(
    val imgWidth: Int,
    val imgHeight: Int,
    val imageType: Int,
    val raster: WritableRaster,
    var colorModel: ColorModel
) : Image(), ImageObserver {

    constructor(width: Int, height: Int, imageType: Int) : this(
        width, height, imageType,
        WritableRaster(width, height, DataBufferInt(width * height)),
        ColorModel.getRGBdefault()
    )

    constructor(width: Int, height: Int, imageType: Int, cm: IndexColorModel?) : this(
        width, height, imageType,
        WritableRaster(width, height, DataBufferByte(width * height)),
        cm ?: ColorModel.getRGBdefault()
    )

    constructor(cm: ColorModel?, raster: WritableRaster?, isRasterPremultiplied: Boolean, properties: Any?) : this(
        raster?.width ?: 1, raster?.height ?: 1, TYPE_CUSTOM,
        raster ?: WritableRaster(1, 1, DataBufferInt(1)),
        cm ?: ColorModel.getRGBdefault()
    )

    override fun getWidth(observer: ImageObserver?): Int = imgWidth
    override fun getHeight(observer: ImageObserver?): Int = imgHeight
    open fun getType(): Int = imageType
    open fun getRGB(x: Int, y: Int): Int {
        val db = raster.dataBuffer
        return if (db is DataBufferInt) db.data[y * imgWidth + x] else 0
    }
    open fun setRGB(x: Int, y: Int, rgb: Int) {
        val db = raster.dataBuffer
        if (db is DataBufferInt) db.data[y * imgWidth + x] = rgb
    }
    open fun getRGB(startX: Int, startY: Int, w: Int, h: Int, rgbArray: IntArray?, offset: Int, scansize: Int): IntArray {
        val result = rgbArray ?: IntArray(w * h)
        val db = raster.dataBuffer
        if (db is DataBufferInt) {
            for (row in 0 until h) {
                System.arraycopy(db.data, (startY + row) * imgWidth + startX, result, offset + row * scansize, w)
            }
        }
        return result
    }
    open fun setRGB(startX: Int, startY: Int, w: Int, h: Int, rgbArray: IntArray, offset: Int, scansize: Int) {
        val db = raster.dataBuffer
        if (db is DataBufferInt) {
            for (row in 0 until h) {
                System.arraycopy(rgbArray, offset + row * scansize, db.data, (startY + row) * imgWidth + startX, w)
            }
        }
    }
    open fun getSubimage(x: Int, y: Int, w: Int, h: Int): BufferedImage = BufferedImage(w, h, imageType)
    open fun createGraphics(): Graphics2D = Graphics2D()
    override fun getGraphics(): Graphics = createGraphics()
    open fun getScaledInstance(width: Int, height: Int, hints: Int): Image = BufferedImage(width, height, imageType)
    open fun getSource(): ImageProducer? = null
    open fun getProperty(name: String?): Any? = null
    open fun getPropertyNames(): Array<String>? = null
    open fun getAlphaRaster(): WritableRaster? = null
    open fun isAlphaPremultiplied(): Boolean = false
    open fun coerceData(isAlphaPremultiplied: Boolean) {}
    open fun getTransparency(): Int = Transparency.OPAQUE
    open fun getMinX(): Int = 0
    open fun getMinY(): Int = 0
    open fun getTileWidth(): Int = imgWidth
    open fun getTileHeight(): Int = imgHeight

    override fun imageUpdate(img: Image?, infoflags: Int, x: Int, y: Int, width: Int, height: Int): Boolean = true

    companion object {
        const val TYPE_CUSTOM = 0
        const val TYPE_INT_RGB = 1
        const val TYPE_INT_ARGB = 2
        const val TYPE_INT_ARGB_PRE = 3
        const val TYPE_INT_BGR = 4
        const val TYPE_3BYTE_BGR = 5
        const val TYPE_4BYTE_ABGR = 6
        const val TYPE_4BYTE_ABGR_PRE = 7
        const val TYPE_USHORT_565_RGB = 8
        const val TYPE_USHORT_555_RGB = 9
        const val TYPE_BYTE_GRAY = 10
        const val TYPE_USHORT_GRAY = 11
        const val TYPE_BYTE_BINARY = 12
        const val TYPE_BYTE_INDEXED = 13
    }
}

// ============ VolatileImage ============

open class VolatileImage(val imgWidth: Int = 1, val imgHeight: Int = 1) : Image() {
    override fun getWidth(observer: ImageObserver?): Int = imgWidth
    override fun getHeight(observer: ImageObserver?): Int = imgHeight
    open fun createGraphics(): Graphics2D = Graphics2D()
    override fun getGraphics(): Graphics = createGraphics()
    open fun validate(gc: GraphicsConfiguration?): Int = IMAGE_OK
    open fun contentsLost(): Boolean = false
    open fun getCapabilities(): Any? = null
    open fun getSnapshot(): BufferedImage = BufferedImage(imgWidth, imgHeight, BufferedImage.TYPE_INT_ARGB)
    open fun getTransparency(): Int = Transparency.OPAQUE

    companion object {
        const val IMAGE_OK = 0
        const val IMAGE_RESTORED = 1
        const val IMAGE_INCOMPATIBLE = 2
    }
}

// ============ ImageProducer / ImageConsumer / ImageFilter ============

interface ImageProducer {
    fun addConsumer(ic: ImageConsumer?) {}
    fun removeConsumer(ic: ImageConsumer?) {}
    fun startProduction(ic: ImageConsumer?) {}
    fun requestTopDownLeftRightResend(ic: ImageConsumer?) {}
    fun isConsumer(ic: ImageConsumer?): Boolean = false
}

interface ImageConsumer {
    fun setDimensions(width: Int, height: Int) {}
    fun setPixels(x: Int, y: Int, w: Int, h: Int, model: ColorModel?, pixels: IntArray?, off: Int, scansize: Int) {}
    fun imageComplete(status: Int) {}
    fun setProperties(props: java.util.Hashtable<*, *>?) {}

    companion object {
        const val RANDOMPIXELORDER = 1
        const val TOPDOWNLEFTRIGHT = 2
        const val COMPLETESCANLINES = 4
        const val SINGLEPASS = 8
        const val SINGLEFRAME = 16
        const val STATICIMAGEDONE = 3
        const val SINGLEFRAMEDONE = 2
        const val IMAGEERROR = 1
        const val IMAGEABORTED = 4
    }
}

open class FilteredImageSource(val producer: ImageProducer?, val filter: ImageFilter?) : ImageProducer

open class ImageFilter : ImageConsumer {
    open var consumer: ImageConsumer? = null
    open fun getFilterInstance(ic: ImageConsumer?): ImageFilter { consumer = ic; return this }
}

open class RGBImageFilter : ImageFilter() {
    open var canFilterIndexColorModel: Boolean = true
    open fun filterRGB(x: Int, y: Int, rgb: Int): Int = rgb
}

open class PixelGrabber : ImageConsumer {
    var pixels: IntArray? = null
        private set

    constructor(img: Image?, x: Int, y: Int, w: Int, h: Int, pix: IntArray, off: Int, scansize: Int) {
        pixels = pix
    }

    constructor(img: Image?, x: Int, y: Int, w: Int, h: Int, forceRGB: Boolean) {
        val width = if (w == -1) 1 else w
        val height = if (h == -1) 1 else h
        pixels = IntArray(width * height)
    }

    constructor(producer: ImageProducer?, x: Int, y: Int, w: Int, h: Int, pix: IntArray, off: Int, scansize: Int) {
        pixels = pix
    }

    open fun grabPixels(): Boolean = true
    open fun grabPixels(ms: Long): Boolean = true
    open fun getStatus(): Int = ImageObserver.ALLBITS
}

open class MemoryImageSource : ImageProducer {
    constructor(w: Int, h: Int, pix: IntArray, off: Int, scan: Int)
    constructor(w: Int, h: Int, cm: ColorModel?, pix: IntArray, off: Int, scan: Int)
    constructor(w: Int, h: Int, cm: ColorModel?, pix: ByteArray, off: Int, scan: Int)

    open fun setAnimated(animated: Boolean) {}
    open fun setFullBufferUpdates(fullbuffers: Boolean) {}
    open fun newPixels() {}
    open fun newPixels(x: Int, y: Int, w: Int, h: Int) {}
    open fun newPixels(newpix: IntArray?, newmodel: ColorModel?, offset: Int, scansize: Int) {}
    open fun newPixels(newpix: ByteArray?, newmodel: ColorModel?, offset: Int, scansize: Int) {}
}

// ============ AffineTransformOp (placeholder) ============

open class AffineTransformOp(val transform: Any?, val interpolationType: Int) {
    companion object {
        const val TYPE_NEAREST_NEIGHBOR = 1
        const val TYPE_BILINEAR = 2
        const val TYPE_BICUBIC = 3
    }

    open fun filter(src: BufferedImage?, dst: BufferedImage?): BufferedImage? = dst ?: src
}

// ============ BufferedImageOp ============

interface BufferedImageOp {
    fun filter(src: BufferedImage?, dest: BufferedImage?): BufferedImage?
    fun getBounds2D(src: BufferedImage?): Any? = null
    fun createCompatibleDestImage(src: BufferedImage?, destCM: ColorModel?): BufferedImage? = null
    fun getPoint2D(srcPt: Any?, dstPt: Any?): Any? = dstPt
    fun getRenderingHints(): RenderingHints? = null
}

// ============ LookupTable / LookupOp ============

open class LookupTable(val offset: Int, val numComponents: Int) {
    open fun lookupPixel(src: IntArray?, dest: IntArray?): IntArray? = dest ?: src
}

open class ByteLookupTable(offset: Int, val data: Array<ByteArray>) : LookupTable(offset, data.size) {
    constructor(offset: Int, data: ByteArray) : this(offset, arrayOf(data))
}

open class ShortLookupTable(offset: Int, val data: Array<ShortArray>) : LookupTable(offset, data.size) {
    constructor(offset: Int, data: ShortArray) : this(offset, arrayOf(data))
}

open class LookupOp(val table: LookupTable?, val hints: RenderingHints?) : BufferedImageOp {
    override fun filter(src: BufferedImage?, dest: BufferedImage?): BufferedImage? = dest ?: src
}

// ============ ColorConvertOp ============

open class ColorConvertOp(val hints: RenderingHints?) : BufferedImageOp {
    constructor(srcCS: Any?, destCS: Any?, hints: RenderingHints?) : this(hints)
    override fun filter(src: BufferedImage?, dest: BufferedImage?): BufferedImage? = dest ?: src
}

// ============ RescaleOp ============

open class RescaleOp(val scaleFactors: FloatArray, val offsets: FloatArray, val hints: RenderingHints?) : BufferedImageOp {
    constructor(scaleFactor: Float, offset: Float, hints: RenderingHints?) : this(floatArrayOf(scaleFactor), floatArrayOf(offset), hints)
    override fun filter(src: BufferedImage?, dest: BufferedImage?): BufferedImage? = dest ?: src
}

// ============ ConvolveOp / Kernel ============

open class Kernel(val width: Int, val height: Int, val data: FloatArray) {
    open fun getKernelData(data: FloatArray?): FloatArray = this.data
}

open class ConvolveOp(val kernel: Kernel?, val edgeCondition: Int = EDGE_ZERO_FILL, val hints: RenderingHints? = null) : BufferedImageOp {
    companion object {
        const val EDGE_ZERO_FILL = 0
        const val EDGE_NO_OP = 1
    }
    override fun filter(src: BufferedImage?, dest: BufferedImage?): BufferedImage? = dest ?: src
}

// ============ BandCombineOp (stub) ============

open class BandCombineOp(val matrix: Array<FloatArray>?, val hints: RenderingHints?) {
    open fun filter(src: Raster?, dest: WritableRaster?): WritableRaster? = dest
}
