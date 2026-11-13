package io.github.mariokovacevic.baresipkit.video

import android.graphics.Bitmap
import io.github.mariokovacevic.baresipkit.BaresipPixelFormat
import io.github.mariokovacevic.baresipkit.BaresipVideoFrame
import java.nio.ByteBuffer
import java.nio.ByteOrder

internal class StagedFrame(
    val format: BaresipPixelFormat,
    val width: Int,
    val height: Int,
    val rotationDegrees: Int,
    val y: ByteBuffer,
    val u: ByteBuffer,
    val v: ByteBuffer?,
) {
    val chromaWidth: Int get() = (width + 1) / 2
    val chromaHeight: Int get() = (height + 1) / 2

    fun argb(): IntArray {
        val pixels = IntArray(width * height)
        for (row in 0 until height) {
            for (col in 0 until width) {
                val luma = y.get(row * width + col).toInt() and 0xff
                val cu: Int
                val cv: Int
                val c = (row / 2) * chromaWidth + col / 2
                if (format == BaresipPixelFormat.NV12) {
                    cu = u.get(2 * c).toInt() and 0xff
                    cv = u.get(2 * c + 1).toInt() and 0xff
                } else {
                    cu = u.get(c).toInt() and 0xff
                    cv = (v ?: u).get(c).toInt() and 0xff
                }
                pixels[row * width + col] = yuvToArgb(luma, cu, cv)
            }
        }
        return pixels
    }

    fun bitmap(): Bitmap = Bitmap.createBitmap(argb(), width, height, Bitmap.Config.ARGB_8888)

    companion object {
        fun of(
            frame: BaresipVideoFrame,
            reuse: StagedFrame?,
        ): StagedFrame? {
            if (frame.format == BaresipPixelFormat.BGRA) return null
            val width = frame.width
            val height = frame.height
            val cw = (width + 1) / 2
            val ch = (height + 1) / 2
            val nv12 = frame.format == BaresipPixelFormat.NV12
            val y = buffer(reuse?.y, width * height)
            val u = buffer(reuse?.u, if (nv12) 2 * cw * ch else cw * ch)
            val v = if (nv12) null else buffer(reuse?.v, cw * ch)
            pack(frame.planes[0] ?: return null, frame.strides[0], width, height, y)
            pack(frame.planes[1] ?: return null, frame.strides[1], if (nv12) 2 * cw else cw, ch, u)
            if (v != null) pack(frame.planes[2] ?: return null, frame.strides[2], cw, ch, v)
            return StagedFrame(frame.format, width, height, frame.rotationDegrees, y, u, v)
        }

        private fun buffer(
            reuse: ByteBuffer?,
            size: Int,
        ): ByteBuffer =
            if (reuse != null && reuse.capacity() == size) {
                reuse.clear()
                reuse
            } else {
                ByteBuffer.allocateDirect(size).order(ByteOrder.nativeOrder())
            }

        fun pack(
            source: ByteBuffer,
            stride: Int,
            rowBytes: Int,
            rows: Int,
            target: ByteBuffer,
        ) {
            val row = ByteArray(rowBytes)
            target.clear()
            for (index in 0 until rows) {
                source.position(index * stride)
                source.get(row, 0, rowBytes)
                target.put(row)
            }
            target.flip()
            source.rewind()
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
}
