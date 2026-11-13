package io.github.mariokovacevic.baresipkit.zvono.model

import android.graphics.Bitmap
import io.github.mariokovacevic.baresipkit.BaresipCallID
import io.github.mariokovacevic.baresipkit.BaresipVideoFrame
import io.github.mariokovacevic.baresipkit.BaresipVideoRenderer
import java.io.File
import java.util.concurrent.Executors

class CallPreviewFeed(
    val call: BaresipCallID,
    val file: File,
    private val onPicture: (Bitmap) -> Unit,
) : BaresipVideoRenderer {
    private val lock = Any()
    private val throttle = PictureThrottle()
    private val writer =
        Executors.newSingleThreadExecutor { runnable -> Thread(runnable, "zvono.preview-feed").apply { isDaemon = true } }
    private var display: BaresipVideoRenderer? = null
    private var stopped = false

    @Volatile var latest: Bitmap? = null
        private set

    fun setDisplay(renderer: BaresipVideoRenderer?) {
        synchronized(lock) { display = renderer }
    }

    fun removeDisplay(renderer: BaresipVideoRenderer) {
        synchronized(lock) { if (display === renderer) display = null }
    }

    fun stop() {
        synchronized(lock) {
            stopped = true
            display = null
        }
        writer.execute { file.delete() }
        writer.shutdown()
    }

    override fun render(frame: BaresipVideoFrame) {
        val shown =
            synchronized(lock) {
                if (stopped) return
                display
            }
        shown?.render(frame)
        if (!throttle.take(System.currentTimeMillis())) return
        val planes =
            runCatching { FramePictures.copy(frame, MAXIMUM_WIDTH) }.getOrNull() ?: run {
                throttle.finished()
                return
            }
        runCatching {
            writer.execute {
                try {
                    val picture = planes.bitmap() ?: return@execute
                    if (synchronized(lock) { stopped }) return@execute
                    file.parentFile?.mkdirs()
                    val temporary = File(file.path + ".part")
                    temporary.outputStream().use { picture.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, it) }
                    temporary.renameTo(file)
                    latest = picture
                    onPicture(picture)
                } catch (_: Throwable) {
                } finally {
                    throttle.finished()
                }
            }
        }.onFailure { throttle.finished() }
    }

    override fun didChangeSize(
        width: Int,
        height: Int,
    ) {
        synchronized(lock) { display }?.didChangeSize(width, height)
    }

    private companion object {
        const val MAXIMUM_WIDTH = 480
        const val JPEG_QUALITY = 60
    }
}
