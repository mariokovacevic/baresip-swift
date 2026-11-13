package io.github.mariokovacevic.baresipkit

import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference

class VideoTest {
    @Before
    fun requireHostCore() = HostCore.require()

    private class Counter : BaresipVideoRenderer {
        val frames = AtomicInteger()
        val size = AtomicReference<Pair<Int, Int>>()
        val firstLuma = AtomicReference<Int>()

        override fun render(frame: BaresipVideoFrame) {
            val y = frame.planes[0] ?: return
            firstLuma.compareAndSet(null, y.get(0).toInt() and 0xff)
            assertTrue(y.capacity() >= frame.strides[0] * frame.height)
            frames.incrementAndGet()
        }

        override fun didChangeSize(
            width: Int,
            height: Int,
        ) {
            size.set(width to height)
        }
    }

    @Test
    fun thePreviewDeliversFramesToTheRendererUntilItStops() =
        runBlocking {
            val base = HostCore.configuration()
            val configuration = base.copy(video = base.video.copy(sourceModule = "fakevideo", width = 320, height = 240, framesPerSecond = 15))
            BaresipEngine(configuration).use { engine ->
                engine.start()
                val renderer = Counter()
                engine.startVideoPreview(renderer = renderer)
                repeat(100) {
                    if (renderer.frames.get() >= 5) return@repeat
                    delay(20)
                }
                assertTrue("frames: ${renderer.frames.get()}", renderer.frames.get() >= 5)
                assertEquals(320 to 240, renderer.size.get())
                engine.stopVideoPreview()
                val stopped = renderer.frames.get()
                delay(300)
                assertTrue(renderer.frames.get() <= stopped + 1)
                engine.stop()
            }
        }

    @Test
    fun aRendererForAnUnknownCallIsRejected() =
        runBlocking {
            BaresipEngine(HostCore.configuration()).use { engine ->
                engine.start()
                val error = runCatching { engine.setVideoRenderer(Counter(), BaresipCallID(4242)) }.exceptionOrNull()
                assertEquals(BaresipError.Code.NOT_FOUND, (error as BaresipError).code)
                engine.stop()
            }
        }

    @Test
    fun cameraPositions() {
        assertEquals("front", BaresipCameraPosition.FRONT.deviceName)
        assertEquals(BaresipCameraPosition.BACK, BaresipCameraPosition.FRONT.toggled)
        assertTrue(BaresipCameraPosition.FRONT.isMirroredInPreview)
    }
}
