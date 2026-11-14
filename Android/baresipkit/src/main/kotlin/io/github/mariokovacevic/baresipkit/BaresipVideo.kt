package io.github.mariokovacevic.baresipkit

import io.github.mariokovacevic.baresipkit.internal.Native
import java.nio.ByteBuffer
import kotlin.time.Duration

/** The pixel layout of a [BaresipVideoFrame]. */
public enum class BaresipPixelFormat {
    /** A luma plane and one interleaved chroma plane (U then V). */
    NV12,

    /** Three planes: luma, U and V. */
    I420,

    /** One plane of 32-bit BGRA pixels. */
    BGRA,
    ;

    internal companion object {
        fun of(code: Int): BaresipPixelFormat = entries.getOrElse(code) { I420 }
    }
}

/**
 * A video frame delivered to a [BaresipVideoRenderer].
 *
 * The planes point at the engine's memory and are valid only during
 * [BaresipVideoRenderer.render]; copy what you need before returning.
 *
 * The constructor of this type is not covered by Semantic Versioning; read its properties.
 */
public class BaresipVideoFrame(
    /** The pixel layout. */
    public val format: BaresipPixelFormat,
    /** The width in pixels. */
    public val width: Int,
    /** The height in pixels. */
    public val height: Int,
    /** The planes: luma first; `null` for planes the format does not have. */
    public val planes: List<ByteBuffer?>,
    /** The bytes per row of each plane. */
    public val strides: List<Int>,
    /** The presentation time stamp. */
    public val timestamp: Duration,
    /** The clockwise rotation to apply when displaying the frame: 0, 90, 180 or 270. */
    public val rotationDegrees: Int,
)

/**
 * Receives the frames of a call's local or remote video, or of the camera preview. Attach a
 * renderer with [BaresipEngine.setVideoRenderer] or [BaresipEngine.startVideoPreview]. Both
 * methods are called on a media thread and must return quickly.
 */
public interface BaresipVideoRenderer {
    /** Called for every frame. */
    public fun render(frame: BaresipVideoFrame)

    /** Called when the frame size changes. */
    public fun didChangeSize(
        width: Int,
        height: Int,
    )
}

/** A camera of the device. */
public enum class BaresipCameraPosition {
    /** The camera on the screen side, the default for calls. */
    FRONT,

    /** The camera on the back. */
    BACK,
    ;

    /** The device name to pass to [BaresipEngine.setCamera]. */
    public val deviceName: String
        get() = name.lowercase()

    /** The other camera. */
    public val toggled: BaresipCameraPosition
        get() = if (this == FRONT) BACK else FRONT

    /** Whether a picture from this camera is usually shown mirrored to the person in front of it. */
    public val isMirroredInPreview: Boolean
        get() = this == FRONT
}

/**
 * A running camera source of the engine. The engine's `bskcamera` video source asks the installed
 * [BaresipCameraHost] to start a camera for it; the host then pushes the camera's frames here.
 *
 * Plumbing between baresipkit and baresipkit-video: apps use `BaresipCamera` instead. Not covered
 * by Semantic Versioning.
 */
@BaresipInternalApi
public class BaresipCameraSource internal constructor(
    internal val handle: Long,
) {
    /**
     * Passes one YUV 4:2:0 frame, as an `ImageReader` delivers `YUV_420_888` images, to the
     * engine. The frame is rotated by [rotationDegrees] clockwise before it is encoded, so the
     * peer sees it upright.
     *
     * @return `false` when the source has stopped.
     */
    public fun push(
        width: Int,
        height: Int,
        y: ByteBuffer,
        u: ByteBuffer,
        v: ByteBuffer,
        yStride: Int,
        uvStride: Int,
        uvPixelStride: Int,
        timestamp: Duration,
        rotationDegrees: Int,
    ): Boolean =
        Native.cameraPush(
            handle,
            width,
            height,
            y,
            u,
            v,
            yStride,
            uvStride,
            uvPixelStride,
            timestamp.inWholeMicroseconds,
            rotationDegrees,
        )

    override fun equals(other: Any?): Boolean = other is BaresipCameraSource && other.handle == handle

    override fun hashCode(): Int = handle.hashCode()

    override fun toString(): String = "camera#$handle"
}

/**
 * Opens cameras for the engine's `bskcamera` video source; see [BaresipCameraSource].
 *
 * Plumbing between baresipkit and baresipkit-video: apps call `BaresipCamera.install` instead. Not
 * covered by Semantic Versioning.
 */
@BaresipInternalApi
public interface BaresipCameraHost {
    /**
     * Starts the camera named [device] (`front`, `back` or a camera id) for [source] at about
     * [width] by [height] pixels and [fps] frames per second. Return quickly and open the camera
     * asynchronously.
     *
     * @return `false` when there is no such camera or it cannot be used.
     */
    public fun start(
        source: BaresipCameraSource,
        device: String,
        width: Int,
        height: Int,
        fps: Int,
    ): Boolean

    /** Stops the camera of [source]. No frame of it is accepted afterwards. */
    public fun stop(source: BaresipCameraSource)

    /** Switches [source] to the camera named [device]. */
    public fun switchDevice(
        source: BaresipCameraSource,
        device: String,
    ): Boolean

    public companion object {
        @Volatile internal var installed: BaresipCameraHost? = null

        /** Makes [host] the camera of every engine in the process, or removes it with `null`. */
        @BaresipInternalApi
        public fun install(host: BaresipCameraHost?) {
            installed = host
            Native.cameraInstallHost(host != null)
        }
    }
}

internal class VideoSinkBox(
    val renderer: BaresipVideoRenderer,
) {
    val pointer: Long = Native.sinkCreate(this)

    fun release() = Native.sinkRelease(pointer)
}

internal data class VideoSinkKey(
    val call: BaresipCallID?,
    val local: Boolean,
)
