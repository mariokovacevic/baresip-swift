package io.github.mariokovacevic.baresipkit.video

import io.github.mariokovacevic.baresipkit.BaresipPixelFormat
import io.github.mariokovacevic.baresipkit.BaresipVideoFrame
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Test
import java.nio.ByteBuffer
import kotlin.time.Duration

class VideoGeometryTest {
    private fun corner(
        quad: FloatArray,
        vertex: Int,
    ) = floatArrayOf(quad[vertex * 4], quad[vertex * 4 + 1], quad[vertex * 4 + 2], quad[vertex * 4 + 3])

    @Test
    fun anUnrotatedFrameFillsTheViewWithTheTopRowAtTheTop() {
        val quad = VideoGeometry.quad(640, 480, 0, 640, 480, fill = true, mirrored = false)
        assertArrayEquals(floatArrayOf(-1f, -1f, 0f, 1f), corner(quad, 0), 0f)
        assertArrayEquals(floatArrayOf(1f, 1f, 1f, 0f), corner(quad, 3), 0f)
    }

    @Test
    fun aQuarterTurnShowsTheOldBottomLeftAtTheTopLeft() {
        val quad = VideoGeometry.quad(640, 480, 90, 480, 640, fill = true, mirrored = false)
        assertArrayEquals(floatArrayOf(-1f, 1f, 0f, 1f), corner(quad, 2), 0f)
        assertArrayEquals(floatArrayOf(1f, 1f, 0f, 0f), corner(quad, 3), 0f)
    }

    @Test
    fun fitLetterboxesAndFillCrops() {
        val fit = VideoGeometry.quad(640, 360, 0, 400, 400, fill = false, mirrored = false)
        assertEquals(1f, fit[4], 0.0001f)
        assertEquals(-0.5625f, fit[1], 0.0001f)
        val fill = VideoGeometry.quad(640, 360, 0, 400, 400, fill = true, mirrored = false)
        assertEquals(1.7778f, fill[4], 0.0001f)
        assertEquals(-1f, fill[1], 0.0001f)
    }

    @Test
    fun mirroringFlipsTheHorizontalPosition() {
        val quad = VideoGeometry.quad(640, 480, 0, 640, 480, fill = true, mirrored = true)
        assertEquals(1f, quad[0], 0f)
        assertEquals(0f, quad[2], 0f)
    }

    @Test
    fun cameraRotationFollowsTheSensorAndTheDisplay() {
        assertEquals(270, CameraSizes.rotation(270, 0, front = true))
        assertEquals(90, CameraSizes.rotation(90, 0, front = false))
        assertEquals(0, CameraSizes.rotation(270, 90, front = true))
        assertEquals(0, CameraSizes.rotation(90, 90, front = false))
    }

    @Test
    fun theClosestCameraSizeIsAtLeastTheRequestedOne() {
        val sizes = listOf(1920 to 1080, 1280 to 720, 640 to 480, 320 to 240)
        assertEquals(640 to 480, CameraSizes.closest(sizes, 640, 480))
        assertEquals(1280 to 720, CameraSizes.closest(sizes, 1000, 700))
        assertEquals(1920 to 1080, CameraSizes.closest(sizes, 4000, 3000))
    }

    @Test
    fun theFpsRangeReachesTheWantedRate() {
        assertEquals(15 to 30, CameraSizes.fpsRange(listOf(7 to 15, 15 to 30, 30 to 30), 30))
        assertEquals(7 to 15, CameraSizes.fpsRange(listOf(7 to 15, 15 to 30), 15))
    }

    @Test
    fun framesAreStagedWithoutRowPaddingAndConvertedToRgb() {
        val y = ByteBuffer.wrap(byteArrayOf(16, 16, 0, 0, -21, -21, 0, 0))
        val u = ByteBuffer.wrap(byteArrayOf(-128, 0))
        val v = ByteBuffer.wrap(byteArrayOf(-128, 0))
        val frame = BaresipVideoFrame(BaresipPixelFormat.I420, 2, 2, listOf(y, u, v), listOf(4, 2, 2), Duration.ZERO, 0)
        val staged = StagedFrame.of(frame, null)!!
        val pixels = staged.argb()
        assertEquals(0xff000000.toInt(), pixels[0])
        assertEquals(0xffffffff.toInt(), pixels[2])
    }
}
