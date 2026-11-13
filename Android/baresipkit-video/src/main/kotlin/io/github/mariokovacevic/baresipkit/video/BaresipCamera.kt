package io.github.mariokovacevic.baresipkit.video

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.ImageFormat
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.hardware.camera2.params.OutputConfiguration
import android.hardware.camera2.params.SessionConfiguration
import android.media.ImageReader
import android.os.Handler
import android.os.HandlerThread
import android.util.Range
import android.util.Size
import android.view.Surface
import android.view.WindowManager
import io.github.mariokovacevic.baresipkit.BaresipCameraHost
import io.github.mariokovacevic.baresipkit.BaresipCameraSource
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executor
import kotlin.time.Duration.Companion.nanoseconds

/**
 * The device cameras as the engine's video source, through Camera2. Install it once, for example
 * in `Application.onCreate`, and keep the engine's video source module `bskcamera`:
 *
 * ```kotlin
 * BaresipCamera.install(context)
 * ```
 *
 * The app needs the `CAMERA` permission before a call sends video. Frames are rotated upright for
 * the display's current rotation before they are encoded.
 */
class BaresipCamera private constructor(
    context: Context,
) : BaresipCameraHost {
    private val context = context.applicationContext
    private val manager = this.context.getSystemService(CameraManager::class.java)
    private val thread = HandlerThread("baresipkit.camera").apply { start() }
    private val handler = Handler(thread.looper)
    private val executor = Executor { handler.post(it) }
    private val captures = ConcurrentHashMap<BaresipCameraSource, Capture>()

    private inner class Capture(
        val source: BaresipCameraSource,
        val width: Int,
        val height: Int,
        val fps: Int,
    ) {
        var cameraId: String? = null
        var device: CameraDevice? = null
        var session: CameraCaptureSession? = null
        var reader: ImageReader? = null
        var front = true
        var sensorOrientation = 0

        @Volatile var closed = false

        @SuppressLint("MissingPermission")
        fun open(id: String) {
            close()
            closed = false
            cameraId = id
            val characteristics = manager.getCameraCharacteristics(id)
            front = characteristics.get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_FRONT
            sensorOrientation = characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 0
            val sizes =
                characteristics
                    .get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
                    ?.getOutputSizes(ImageFormat.YUV_420_888)
                    .orEmpty()
                    .toList()
            val size = CameraSizes.closest(sizes.map { it.width to it.height }, width, height)?.let { Size(it.first, it.second) } ?: Size(width, height)
            val ranges = characteristics.get(CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES).orEmpty()
            val range = CameraSizes.fpsRange(ranges.map { it.lower to it.upper }, fps)?.let { Range(it.first, it.second) }
            val imageReader = ImageReader.newInstance(size.width, size.height, ImageFormat.YUV_420_888, 3)
            imageReader.setOnImageAvailableListener({ reader -> deliver(reader) }, handler)
            reader = imageReader
            manager.openCamera(
                id,
                executor,
                object : CameraDevice.StateCallback() {
                    override fun onOpened(camera: CameraDevice) {
                        if (closed) {
                            camera.close()
                            return
                        }
                        device = camera
                        startSession(camera, imageReader.surface, range)
                    }

                    override fun onDisconnected(camera: CameraDevice) = camera.close()

                    override fun onError(
                        camera: CameraDevice,
                        error: Int,
                    ) = camera.close()
                },
            )
        }

        private fun startSession(
            camera: CameraDevice,
            surface: Surface,
            range: Range<Int>?,
        ) {
            val configuration =
                SessionConfiguration(
                    SessionConfiguration.SESSION_REGULAR,
                    listOf(OutputConfiguration(surface)),
                    executor,
                    object : CameraCaptureSession.StateCallback() {
                        override fun onConfigured(captureSession: CameraCaptureSession) {
                            if (closed) {
                                captureSession.close()
                                return
                            }
                            session = captureSession
                            val request = camera.createCaptureRequest(CameraDevice.TEMPLATE_RECORD)
                            request.addTarget(surface)
                            range?.let { request.set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, it) }
                            captureSession.setRepeatingRequest(request.build(), null, handler)
                        }

                        override fun onConfigureFailed(captureSession: CameraCaptureSession) = captureSession.close()
                    },
                )
            camera.createCaptureSession(configuration)
        }

        private fun deliver(reader: ImageReader) {
            val image = reader.acquireLatestImage() ?: return
            try {
                if (closed) return
                val planes = image.planes
                val rotation = CameraSizes.rotation(sensorOrientation, displayRotationDegrees(), front)
                source.push(
                    image.width,
                    image.height,
                    planes[0].buffer,
                    planes[1].buffer,
                    planes[2].buffer,
                    planes[0].rowStride,
                    planes[1].rowStride,
                    planes[1].pixelStride,
                    image.timestamp.nanoseconds,
                    rotation,
                )
            } finally {
                image.close()
            }
        }

        fun close() {
            closed = true
            runCatching { session?.close() }
            runCatching { device?.close() }
            runCatching { reader?.close() }
            session = null
            device = null
            reader = null
        }
    }

    override fun start(
        source: BaresipCameraSource,
        device: String,
        width: Int,
        height: Int,
        fps: Int,
    ): Boolean {
        val id = cameraId(device) ?: return false
        val capture = Capture(source, width, height, fps)
        captures[source] = capture
        handler.post { runCatching { capture.open(id) } }
        return true
    }

    override fun stop(source: BaresipCameraSource) {
        val capture = captures.remove(source) ?: return
        capture.closed = true
        handler.post { capture.close() }
    }

    override fun switchDevice(
        source: BaresipCameraSource,
        device: String,
    ): Boolean {
        val capture = captures[source] ?: return false
        val id = cameraId(device) ?: return false
        if (id == capture.cameraId) return true
        handler.post { runCatching { capture.open(id) } }
        return true
    }

    /** The cameras by device name: `front`, `back`, then the other camera ids. */
    fun deviceNames(): List<String> =
        manager.cameraIdList
            .map { id ->
                when (manager.getCameraCharacteristics(id).get(CameraCharacteristics.LENS_FACING)) {
                    CameraCharacteristics.LENS_FACING_FRONT -> "front"
                    CameraCharacteristics.LENS_FACING_BACK -> "back"
                    else -> id
                }
            }.distinct()

    private fun cameraId(device: String): String? {
        val facing =
            when (device) {
                "front" -> CameraCharacteristics.LENS_FACING_FRONT
                "back" -> CameraCharacteristics.LENS_FACING_BACK
                else -> return manager.cameraIdList.firstOrNull { it == device }
            }
        return manager.cameraIdList.firstOrNull {
            manager.getCameraCharacteristics(it).get(CameraCharacteristics.LENS_FACING) == facing
        }
    }

    @Suppress("DEPRECATION")
    private fun displayRotationDegrees(): Int =
        when (context.getSystemService(WindowManager::class.java)?.defaultDisplay?.rotation) {
            Surface.ROTATION_90 -> 90
            Surface.ROTATION_180 -> 180
            Surface.ROTATION_270 -> 270
            else -> 0
        }

    companion object {
        @Volatile private var shared: BaresipCamera? = null

        /** Makes the device cameras the source of the engine's `bskcamera` video source. */
        fun install(context: Context): BaresipCamera =
            synchronized(this) {
                shared ?: BaresipCamera(context).also {
                    shared = it
                    BaresipCameraHost.install(it)
                }
            }
    }
}

internal object CameraSizes {
    fun closest(
        sizes: List<Pair<Int, Int>>,
        width: Int,
        height: Int,
    ): Pair<Int, Int>? {
        val wantLong = maxOf(width, height)
        val wantShort = minOf(width, height)
        return sizes.minByOrNull { (w, h) ->
            val long = maxOf(w, h)
            val short = minOf(w, h)
            val penalty = if (long < wantLong || short < wantShort) 1_000_000 else 0
            penalty + kotlin.math.abs(long - wantLong) + kotlin.math.abs(short - wantShort)
        }
    }

    fun fpsRange(
        ranges: List<Pair<Int, Int>>,
        fps: Int,
    ): Pair<Int, Int>? =
        ranges.filter { it.second >= fps }.minByOrNull { (low, high) -> (high - fps) * 100 - (fps - low).coerceAtLeast(0) }
            ?: ranges.maxByOrNull { it.second }

    fun rotation(
        sensorOrientation: Int,
        displayRotation: Int,
        front: Boolean,
    ): Int =
        if (front) {
            (sensorOrientation + displayRotation) % 360
        } else {
            (sensorOrientation - displayRotation + 360) % 360
        }
}
