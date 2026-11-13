package io.github.mariokovacevic.baresipkit.zvono.model

import android.graphics.Bitmap
import android.graphics.Matrix
import io.github.mariokovacevic.baresipkit.BaresipPixelFormat
import io.github.mariokovacevic.baresipkit.BaresipVideoFrame
import java.nio.ByteBuffer

class FramePlanes(
    val format: BaresipPixelFormat,
    val width: Int,
    val height: Int,
    val rotationDegrees: Int,
    val step: Int,
    val luma: ByteArray,
    val chroma: ByteArray,
    val chromaSecond: ByteArray?,
) {
    val pictureWidth: Int
        get() = width / step

    val pictureHeight: Int
        get() = height / step

    fun argb(): IntArray {
        val outWidth = pictureWidth
        val outHeight = pictureHeight
        val pixels = IntArray(outWidth * outHeight)
        val chromaWidth = (width + 1) / 2
        for (row in 0 until outHeight) {
            val y = row * step
            for (col in 0 until outWidth) {
                val x = col * step
                val color =
                    when (format) {
                        BaresipPixelFormat.BGRA -> {
                            val index = (y * width + x) * 4
                            val blue = luma[index].toInt() and 0xff
                            val green = luma[index + 1].toInt() and 0xff
                            val red = luma[index + 2].toInt() and 0xff
                            (0xff shl 24) or (red shl 16) or (green shl 8) or blue
                        }
                        BaresipPixelFormat.NV12 -> {
                            val c = (y / 2) * chromaWidth + x / 2
                            FramePictures.yuvToArgb(luma[y * width + x].toInt() and 0xff, chroma[2 * c].toInt() and 0xff, chroma[2 * c + 1].toInt() and 0xff)
                        }
                        BaresipPixelFormat.I420 -> {
                            val c = (y / 2) * chromaWidth + x / 2
                            FramePictures.yuvToArgb(
                                luma[y * width + x].toInt() and 0xff,
                                chroma[c].toInt() and 0xff,
                                (chromaSecond ?: chroma)[c].toInt() and 0xff,
                            )
                        }
                    }
                pixels[row * outWidth + col] = color
            }
        }
        return pixels
    }

    fun bitmap(): Bitmap? {
        if (pictureWidth <= 0 || pictureHeight <= 0) return null
        val upright = Bitmap.createBitmap(argb(), pictureWidth, pictureHeight, Bitmap.Config.ARGB_8888)
        if (rotationDegrees % 360 == 0) return upright
        val turn = Matrix().apply { postRotate(rotationDegrees.toFloat()) }
        return Bitmap.createBitmap(upright, 0, 0, upright.width, upright.height, turn, true)
    }
}

object FramePictures {
    fun step(
        width: Int,
        maximumWidth: Int,
    ): Int = ((width + maximumWidth - 1) / maximumWidth.coerceAtLeast(1)).coerceAtLeast(1)

    fun copy(
        frame: BaresipVideoFrame,
        maximumWidth: Int,
    ): FramePlanes? {
        val width = frame.width
        val height = frame.height
        if (width <= 0 || height <= 0) return null
        val chromaWidth = (width + 1) / 2
        val chromaHeight = (height + 1) / 2
        return when (frame.format) {
            BaresipPixelFormat.BGRA -> {
                val pixels = pack(frame.planes[0] ?: return null, frame.strides[0], width * 4, height)
                FramePlanes(frame.format, width, height, frame.rotationDegrees, step(width, maximumWidth), pixels, ByteArray(0), null)
            }
            BaresipPixelFormat.NV12 ->
                FramePlanes(
                    frame.format,
                    width,
                    height,
                    frame.rotationDegrees,
                    step(width, maximumWidth),
                    pack(frame.planes[0] ?: return null, frame.strides[0], width, height),
                    pack(frame.planes[1] ?: return null, frame.strides[1], 2 * chromaWidth, chromaHeight),
                    null,
                )
            BaresipPixelFormat.I420 ->
                FramePlanes(
                    frame.format,
                    width,
                    height,
                    frame.rotationDegrees,
                    step(width, maximumWidth),
                    pack(frame.planes[0] ?: return null, frame.strides[0], width, height),
                    pack(frame.planes[1] ?: return null, frame.strides[1], chromaWidth, chromaHeight),
                    pack(frame.planes[2] ?: return null, frame.strides[2], chromaWidth, chromaHeight),
                )
        }
    }

    private fun pack(
        source: ByteBuffer,
        stride: Int,
        rowBytes: Int,
        rows: Int,
    ): ByteArray {
        val target = ByteArray(rowBytes * rows)
        val view = source.duplicate()
        for (row in 0 until rows) {
            view.position(row * stride)
            view.get(target, row * rowBytes, rowBytes)
        }
        return target
    }

    fun yuvToArgb(
        luma: Int,
        u: Int,
        v: Int,
    ): Int {
        val c = (luma - 16).coerceAtLeast(0) * 1192
        val d = u - 128
        val e = v - 128
        val r = ((c + 1634 * e + 512) shr 10).coerceIn(0, 255)
        val g = ((c - 833 * e - 400 * d + 512) shr 10).coerceIn(0, 255)
        val b = ((c + 2066 * d + 512) shr 10).coerceIn(0, 255)
        return (0xff shl 24) or (r shl 16) or (g shl 8) or b
    }
}
