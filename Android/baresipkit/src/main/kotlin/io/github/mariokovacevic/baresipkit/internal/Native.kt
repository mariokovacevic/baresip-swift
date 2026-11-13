package io.github.mariokovacevic.baresipkit.internal

import io.github.mariokovacevic.baresipkit.BaresipCallEndReason
import io.github.mariokovacevic.baresipkit.BaresipCameraHost
import io.github.mariokovacevic.baresipkit.BaresipCameraSource
import io.github.mariokovacevic.baresipkit.BaresipEngine
import io.github.mariokovacevic.baresipkit.BaresipError
import io.github.mariokovacevic.baresipkit.BaresipLogDomain
import io.github.mariokovacevic.baresipkit.BaresipLogEntry
import io.github.mariokovacevic.baresipkit.BaresipLogLevel
import io.github.mariokovacevic.baresipkit.BaresipPixelFormat
import io.github.mariokovacevic.baresipkit.BaresipVideoFrame
import io.github.mariokovacevic.baresipkit.VideoSinkBox
import java.nio.ByteBuffer
import kotlin.time.Duration.Companion.microseconds

internal object Native {
    init {
        System.loadLibrary("baresipkit")
    }

    @JvmStatic external fun version(): String

    @JvmStatic external fun abiVersion(): Int

    @JvmStatic external fun capabilities(): String

    @JvmStatic external fun encodeContactParameters(
        names: Array<ByteArray>,
        values: Array<ByteArray?>,
    ): String

    @JvmStatic external fun engineCreate(
        owner: Any,
        config: NativeEngineConfig,
    ): Long

    @JvmStatic external fun engineDestroy(handle: Long)

    @JvmStatic external fun engineStart(handle: Long)

    @JvmStatic external fun engineStop(
        handle: Long,
        timeoutMs: Int,
    )

    @JvmStatic external fun engineState(handle: Long): Int

    @JvmStatic external fun engineIsEngineThread(handle: Long): Boolean

    @JvmStatic external fun enginePrepareForPushWakeup(handle: Long)

    @JvmStatic external fun engineSuspend(handle: Long)

    @JvmStatic external fun engineResume(handle: Long)

    @JvmStatic external fun engineNetworkChanged(
        handle: Long,
        reregister: Boolean,
        updateCalls: Boolean,
    )

    @JvmStatic external fun engineAudioSessionActivated(handle: Long)

    @JvmStatic external fun engineAudioSessionDeactivated(handle: Long)

    @JvmStatic external fun engineAudioRouteChanged(handle: Long)

    @JvmStatic external fun engineAudioInterruption(
        handle: Long,
        began: Boolean,
    )

    @JvmStatic external fun accountAdd(
        handle: Long,
        config: NativeAccountConfig,
    ): Long

    @JvmStatic external fun accountRemove(
        handle: Long,
        id: Long,
    )

    @JvmStatic external fun accountSetDefault(
        handle: Long,
        id: Long,
    )

    @JvmStatic external fun accountRegister(
        handle: Long,
        id: Long,
    )

    @JvmStatic external fun accountUnregister(
        handle: Long,
        id: Long,
    )

    @JvmStatic external fun accountSetCredentials(
        handle: Long,
        id: Long,
        user: ByteArray?,
        password: ByteArray?,
    )

    @JvmStatic external fun accountSetContactParams(
        handle: Long,
        id: Long,
        names: Array<ByteArray>,
        values: Array<ByteArray?>,
        reregister: Boolean,
    )

    @JvmStatic external fun accountRegistrationState(
        handle: Long,
        id: Long,
    ): Int

    @JvmStatic external fun accountList(handle: Long): LongArray

    @JvmStatic external fun callMake(
        handle: Long,
        account: Long,
        destination: ByteArray,
        audio: Boolean,
        video: Boolean,
    ): Long

    @JvmStatic external fun callAnswer(
        handle: Long,
        id: Long,
        audio: Boolean,
        video: Boolean,
    )

    @JvmStatic external fun callProgress(
        handle: Long,
        id: Long,
        earlyAudio: Boolean,
        earlyVideo: Boolean,
    )

    @JvmStatic external fun callReject(
        handle: Long,
        id: Long,
        code: Int,
        reason: ByteArray?,
    )

    @JvmStatic external fun callHangup(
        handle: Long,
        id: Long,
    )

    @JvmStatic external fun callHold(
        handle: Long,
        id: Long,
        hold: Boolean,
    )

    @JvmStatic external fun callSetActive(
        handle: Long,
        id: Long,
    )

    @JvmStatic external fun callSendDtmf(
        handle: Long,
        id: Long,
        digits: ByteArray,
        durationMs: Int,
        gapMs: Int,
    )

    @JvmStatic external fun callSetMicrophoneMuted(
        handle: Long,
        id: Long,
        muted: Boolean,
    )

    @JvmStatic external fun callSetAudioDirection(
        handle: Long,
        id: Long,
        direction: Int,
    )

    @JvmStatic external fun callSetVideoDirection(
        handle: Long,
        id: Long,
        direction: Int,
    )

    @JvmStatic external fun callSetCamera(
        handle: Long,
        id: Long,
        device: ByteArray,
    )

    @JvmStatic external fun callRequestKeyframe(
        handle: Long,
        id: Long,
    )

    @JvmStatic external fun callSetVideoMaxBitrate(
        handle: Long,
        id: Long,
        bitsPerSecond: Int,
    )

    @JvmStatic external fun callRestartIce(
        handle: Long,
        id: Long,
    )

    @JvmStatic external fun callRecordStart(
        handle: Long,
        id: Long,
        path: ByteArray,
    )

    @JvmStatic external fun callRecordStop(
        handle: Long,
        id: Long,
    )

    @JvmStatic external fun callTransfer(
        handle: Long,
        id: Long,
        target: ByteArray,
    )

    @JvmStatic external fun callTransferAttended(
        handle: Long,
        id: Long,
        target: Long,
    )

    @JvmStatic external fun callInfo(
        handle: Long,
        id: Long,
        out: LongArray,
    ): Array<String?>

    @JvmStatic external fun callStatistics(
        handle: Long,
        id: Long,
        out: LongArray,
    ): Array<String?>

    @JvmStatic external fun callHeader(
        handle: Long,
        id: Long,
        name: ByteArray,
    ): String?

    @JvmStatic external fun callList(handle: Long): LongArray

    @JvmStatic external fun messageSend(
        handle: Long,
        account: Long,
        peer: ByteArray,
        text: ByteArray,
    ): Long

    @JvmStatic external fun videoDevices(handle: Long): String

    @JvmStatic external fun sinkCreate(box: Any): Long

    @JvmStatic external fun sinkRelease(pointer: Long)

    @JvmStatic external fun callSetVideoSink(
        handle: Long,
        call: Long,
        local: Boolean,
        sink: Long,
    )

    @JvmStatic external fun videoPreviewStart(
        handle: Long,
        device: ByteArray?,
        sink: Long,
    )

    @JvmStatic external fun videoPreviewStop(handle: Long)

    @JvmStatic external fun cameraInstallHost(install: Boolean)

    @JvmStatic external fun cameraPush(
        source: Long,
        width: Int,
        height: Int,
        y: ByteBuffer,
        u: ByteBuffer,
        v: ByteBuffer,
        yStride: Int,
        uvStride: Int,
        uvPixelStride: Int,
        timestampUs: Long,
        rotation: Int,
    ): Boolean

    @JvmStatic
    fun onFrame(
        box: Any,
        format: Int,
        width: Int,
        height: Int,
        y: ByteBuffer?,
        u: ByteBuffer?,
        v: ByteBuffer?,
        yStride: Int,
        uStride: Int,
        vStride: Int,
        timestampUs: Long,
        rotation: Int,
    ) {
        val frame =
            BaresipVideoFrame(
                BaresipPixelFormat.of(format),
                width,
                height,
                listOf(y, u, v),
                listOf(yStride, uStride, vStride),
                timestampUs.microseconds,
                rotation,
            )
        (box as VideoSinkBox).renderer.render(frame)
    }

    @JvmStatic
    fun onFrameSize(
        box: Any,
        width: Int,
        height: Int,
    ) {
        (box as VideoSinkBox).renderer.didChangeSize(width, height)
    }

    @JvmStatic
    fun cameraStart(
        source: Long,
        device: String?,
        width: Int,
        height: Int,
        fps: Int,
    ): Int {
        val host = BaresipCameraHost.installed ?: return NO_DEVICE
        return if (host.start(BaresipCameraSource(source), device ?: "front", width, height, fps)) 0 else NO_DEVICE
    }

    @JvmStatic
    fun cameraStop(source: Long) {
        BaresipCameraHost.installed?.stop(BaresipCameraSource(source))
    }

    @JvmStatic
    fun cameraSwitch(
        source: Long,
        device: String?,
    ): Int {
        val host = BaresipCameraHost.installed ?: return NO_DEVICE
        return if (host.switchDevice(BaresipCameraSource(source), device ?: "front")) 0 else NO_DEVICE
    }

    private const val NO_DEVICE = 19

    @JvmStatic
    fun onEvent(
        owner: Any,
        type: Int,
        account: Long,
        call: Long,
        numbers: LongArray,
        strings: Array<String?>,
        body: ByteArray?,
    ) {
        val event = EventDecoder.decode(type, account, call, numbers, strings, body) ?: return
        (owner as BaresipEngine).deliver(event)
    }

    @JvmStatic
    fun onLog(
        owner: Any,
        level: Int,
        domain: Int,
        line: ByteArray,
    ) {
        val entry = BaresipLogEntry(BaresipLogLevel.of(level), BaresipLogDomain.of(domain), String(line, Charsets.UTF_8))
        (owner as BaresipEngine).deliverLog(entry)
    }

    @JvmStatic
    fun error(
        code: Int,
        errno: Int,
        sipStatus: Int,
        sipReason: String?,
        message: String?,
        endReason: Int,
    ): Throwable =
        BaresipError(
            code = BaresipError.Code.of(code),
            systemErrno = errno,
            sipStatus = sipStatus.takeIf { it != 0 },
            sipReason = sipReason.orEmpty(),
            detail = message.orEmpty(),
            endReason = BaresipCallEndReason.of(endReason),
        )
}

internal fun String.cString(): ByteArray = (this + '\u0000').toByteArray(Charsets.UTF_8)

internal fun String?.cStringOrNull(): ByteArray? = this?.cString()

internal fun List<String>.cStrings(): Array<ByteArray> = Array(size) { this[it].cString() }
