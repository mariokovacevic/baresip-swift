package io.github.mariokovacevic.baresipkit.video

import io.github.mariokovacevic.baresipkit.BaresipVideoFrame
import io.github.mariokovacevic.baresipkit.BaresipVideoRenderer

/**
 * A renderer that forwards frames and size changes to functions.
 *
 * ```kotlin
 * val relay = BaresipVideoFrameRelay(onFrame = { frame -> recorder.append(frame) })
 * engine.setVideoRenderer(relay, call)
 * ```
 */
class BaresipVideoFrameRelay(
    onFrame: ((BaresipVideoFrame) -> Unit)? = null,
    onSize: ((Int, Int) -> Unit)? = null,
) : BaresipVideoRenderer {
    @Volatile private var handlers = onFrame to onSize

    /** Replaces both handlers. */
    fun setHandlers(
        onFrame: ((BaresipVideoFrame) -> Unit)?,
        onSize: ((Int, Int) -> Unit)?,
    ) {
        handlers = onFrame to onSize
    }

    override fun render(frame: BaresipVideoFrame) {
        handlers.first?.invoke(frame)
    }

    override fun didChangeSize(
        width: Int,
        height: Int,
    ) {
        handlers.second?.invoke(width, height)
    }
}
