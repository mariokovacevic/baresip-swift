package io.github.mariokovacevic.baresipkit

import io.github.mariokovacevic.baresipkit.internal.EventDecoder
import io.github.mariokovacevic.baresipkit.internal.Native
import io.github.mariokovacevic.baresipkit.internal.NativeAccountConfig
import io.github.mariokovacevic.baresipkit.internal.NativeEngineConfig
import io.github.mariokovacevic.baresipkit.internal.cString
import io.github.mariokovacevic.baresipkit.internal.cStringOrNull
import io.github.mariokovacevic.baresipkit.internal.names
import io.github.mariokovacevic.baresipkit.internal.values
import io.github.mariokovacevic.baresipkit.internal.wholeMilliseconds
import kotlinx.coroutines.ExecutorCoroutineDispatcher
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.withContext
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.time.Duration
import kotlin.time.Duration.Companion.milliseconds
import kotlin.time.Duration.Companion.seconds

/**
 * A SIP user agent backed by baresip.
 *
 * Create one engine per app, start it, add an account and place or answer calls. All operations
 * are `suspend` functions: they run on the engine's own thread and return when the core has
 * accepted them. What happens afterwards arrives through [events].
 *
 * ```kotlin
 * val engine = BaresipEngine(BaresipConfiguration())
 * engine.start()
 * val account = engine.addAccount(BaresipAccountConfiguration(aor = "sip:alice@example.com") { authPassword = password })
 * engine.register(account)
 * val call = engine.makeCall(destination = "sip:bob@example.com")
 * ```
 *
 * Close the engine with [close] when it is no longer needed; it stops and frees the core.
 *
 * @param configuration Engine-wide settings.
 * @throws BaresipError when the core rejects the configuration.
 */
class BaresipEngine(
    /** The configuration the engine was created with. */
    val configuration: BaresipConfiguration = BaresipConfiguration(),
) : AutoCloseable {
    private val executor: ExecutorService =
        Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "baresipkit.engine").apply { isDaemon = true }
        }
    private val dispatcher: ExecutorCoroutineDispatcher = executor.asCoroutineDispatcher()
    private val closed = AtomicBoolean(false)
    private val eventFlow = MutableSharedFlow<BaresipEvent>(extraBufferCapacity = Int.MAX_VALUE)

    @Volatile private var logHandler: BaresipLogHandler? = null
    private val videoSinks = HashMap<VideoSinkKey, VideoSinkBox>()
    private val handle: Long

    init {
        handle =
            try {
                Native.engineCreate(this, NativeEngineConfig(configuration))
            } catch (error: Throwable) {
                executor.shutdown()
                throw error
            }
    }

    /**
     * Engine events. Every collector receives every event from the moment it subscribes; use
     * `onSubscription` to act once the subscription is in place.
     */
    val events: SharedFlow<BaresipEvent> = eventFlow.asSharedFlow()

    /** Sets the handler that receives engine log output, or removes it with `null`. */
    fun setLogHandler(handler: BaresipLogHandler?) {
        logHandler = handler
    }

    /** The current lifecycle state. */
    val state: BaresipEngineState
        get() = if (closed.get()) BaresipEngineState.STOPPED else BaresipEngineState.of(Native.engineState(handle))

    /** `true` when called on the engine's internal thread, for example from a log handler. */
    val isEngineThread: Boolean
        get() = !closed.get() && Native.engineIsEngineThread(handle)

    /**
     * Starts the engine: loads modules, opens transports and starts the engine thread. Only one
     * engine may run per process.
     *
     * @throws BaresipError when the engine is not idle, another engine is running
     *   ([BaresipError.Code.BUSY]) or the core cannot start.
     */
    suspend fun start() = onEngine { Native.engineStart(handle) }

    /**
     * Stops the engine. Calls are hung up and accounts unregister, within [timeout]. The engine's
     * accounts are removed; add them again after the next [start].
     */
    suspend fun stop(timeout: Duration = 3.seconds) {
        runCatching { onEngine { Native.engineStop(handle, timeout.wholeMilliseconds()) } }
    }

    /**
     * Prepares the engine for an incoming call announced by a push message.
     *
     * A running engine sends a REGISTER for every account that is registered or registering, so
     * the INVITE can arrive on a fresh connection. A stopped engine is started, without
     * accounts: add and register them afterwards.
     */
    suspend fun prepareForPushWakeUp() = onEngine { Native.enginePrepareForPushWakeup(handle) }

    /** Suspends the engine when the app moves to the background without an active call. */
    suspend fun suspend() = onEngine { Native.engineSuspend(handle) }

    /** Resumes an engine suspended with [suspend]. */
    suspend fun resumeFromBackground() = onEngine { Native.engineResume(handle) }

    /**
     * Tells the engine that the network changed, for example from a `ConnectivityManager`
     * callback. The engine reads the local addresses again and opens its transports on them.
     *
     * @param reregister Whether accounts register again on the new address.
     * @param updateCalls Whether active calls move to the new address, restarting ICE when used.
     */
    suspend fun networkDidChange(
        reregister: Boolean = true,
        updateCalls: Boolean = true,
    ) {
        runCatching { onEngine { Native.engineNetworkChanged(handle, reregister, updateCalls) } }
    }

    /** Tells the engine that audio focus was gained and the audio device may start. */
    suspend fun audioSessionDidActivate() {
        runCatching { onEngine { Native.engineAudioSessionActivated(handle) } }
    }

    /** Tells the engine that audio focus was lost for good. */
    suspend fun audioSessionDidDeactivate() {
        runCatching { onEngine { Native.engineAudioSessionDeactivated(handle) } }
    }

    /** Tells the engine that the audio route changed, so audio streams are restarted. */
    suspend fun audioRouteDidChange() {
        runCatching { onEngine { Native.engineAudioRouteChanged(handle) } }
    }

    /** Tells the engine that an audio interruption, such as a cellular call, began or ended. */
    suspend fun audioInterruption(began: Boolean) {
        runCatching { onEngine { Native.engineAudioInterruption(handle, began) } }
    }

    /**
     * Adds an account. The first account added becomes the default for calls and messages.
     * Adding does not register; call [register].
     *
     * @throws BaresipError when the settings are invalid or the engine is not running.
     */
    suspend fun addAccount(account: BaresipAccountConfiguration): BaresipAccountID {
        account.validate()
        val native = NativeAccountConfig(account)
        return BaresipAccountID(onEngine { Native.accountAdd(handle, native) })
    }

    /** Unregisters and removes an account. Its calls are hung up. */
    suspend fun removeAccount(id: BaresipAccountID) = onEngine { Native.accountRemove(handle, id.rawValue) }

    /** Makes an account the default for calls and messages without an explicit account. */
    suspend fun setDefaultAccount(id: BaresipAccountID) = onEngine { Native.accountSetDefault(handle, id.rawValue) }

    /** Starts registration. Progress arrives as [BaresipEvent.Registration]. */
    suspend fun register(account: BaresipAccountID) = onEngine { Native.accountRegister(handle, account.rawValue) }

    /** Removes the registration. */
    suspend fun unregister(account: BaresipAccountID) = onEngine { Native.accountUnregister(handle, account.rawValue) }

    /**
     * Replaces an account's credentials. The next REGISTER uses them.
     *
     * @param authUser The authentication user name, or `null` for the user part of the address.
     */
    suspend fun updateCredentials(
        account: BaresipAccountID,
        authUser: String?,
        password: String,
    ) = onEngine { Native.accountSetCredentials(handle, account.rawValue, authUser.cStringOrNull(), password.cString()) }

    /**
     * Replaces an account's `Contact` parameters, for example when the push token changes.
     *
     * @param reregisterNow Whether to send a REGISTER with the new parameters right away.
     */
    suspend fun updateContactParameters(
        account: BaresipAccountID,
        parameters: List<BaresipContactParameter>,
        reregisterNow: Boolean = true,
    ) {
        encodeContactParameters(parameters)
        onEngine {
            Native.accountSetContactParams(handle, account.rawValue, parameters.names(), parameters.values(), reregisterNow)
        }
    }

    /**
     * The accounts the engine has, each with its current registration state. The result is empty
     * while the engine is not running.
     */
    suspend fun accounts(): Map<BaresipAccountID, BaresipRegistrationState> =
        runCatching {
            onEngine {
                val pairs = Native.accountList(handle)
                (pairs.indices step 2).associate {
                    BaresipAccountID(pairs[it]) to BaresipRegistrationState.of(pairs[it + 1].toInt())
                }
            }
        }.getOrDefault(emptyMap())

    /** The current registration state of an account, or [BaresipRegistrationState.NONE] for an unknown account. */
    fun registrationState(account: BaresipAccountID): BaresipRegistrationState =
        if (closed.get()) {
            BaresipRegistrationState.NONE
        } else {
            BaresipRegistrationState.of(Native.accountRegistrationState(handle, account.rawValue))
        }

    /**
     * Places a call.
     *
     * A destination without a scheme and domain, such as `1002`, is completed with the account's
     * domain. Video is always offered, so the callee's early media and video are shown even in an
     * audio call; [video] only decides whether your camera is sent.
     *
     * @param account The account to call from, or `null` for the default account.
     * @param destination A SIP URI, user name or number.
     * @param video Whether to send your camera.
     * @param audio Whether audio flows. With `false` the audio stream is inactive in both
     *   directions, for example to watch a door station's camera.
     * @return The new call's identifier. State changes arrive as [BaresipEvent.Call].
     */
    suspend fun makeCall(
        account: BaresipAccountID? = null,
        destination: String,
        video: Boolean = false,
        audio: Boolean = true,
    ): BaresipCallID = BaresipCallID(onEngine { Native.callMake(handle, account?.rawValue ?: 0, destination.cString(), audio, video) })

    /**
     * Answers an incoming call. The caller's video, if offered, is always received; [video] only
     * decides whether your camera is sent.
     *
     * @param audio Whether audio flows. With `false` the call is answered silently.
     */
    suspend fun answer(
        call: BaresipCallID,
        video: Boolean = false,
        audio: Boolean = true,
    ) = onEngine { Native.callAnswer(handle, call.rawValue, audio, video) }

    /**
     * Starts a receive-only early media preview of an incoming call with 183 Session Progress.
     * You hear the caller, and with [earlyVideo] see them; the caller neither hears nor sees you
     * until [answer].
     */
    suspend fun sendProgress(
        call: BaresipCallID,
        earlyVideo: Boolean = false,
        earlyAudio: Boolean = true,
    ) = onEngine { Native.callProgress(handle, call.rawValue, earlyAudio, earlyVideo) }

    /**
     * Rejects an incoming call that is still ringing. End an answered call with [hangup].
     *
     * @param statusCode The SIP response code, 486 Busy Here by default.
     * @param reason The reason phrase, or `null` for the standard phrase.
     */
    suspend fun reject(
        call: BaresipCallID,
        statusCode: Int = 486,
        reason: String? = null,
    ) = onEngine { Native.callReject(handle, call.rawValue, statusCode.coerceIn(0, MAXIMUM_SIP_STATUS), reason.cStringOrNull()) }

    /** Hangs up a call in any state. */
    suspend fun hangup(call: BaresipCallID) = onEngine { Native.callHangup(handle, call.rawValue) }

    /**
     * Puts a call on hold. When the other side rejects the hold, the call returns to its previous
     * state with an error in the event.
     */
    suspend fun hold(call: BaresipCallID) = onEngine { Native.callHold(handle, call.rawValue, true) }

    /** Resumes a call from hold. */
    suspend fun resume(call: BaresipCallID) = onEngine { Native.callHold(handle, call.rawValue, false) }

    /** Makes a call the active one: other established calls are put on hold, and this call is resumed. */
    suspend fun setActiveCall(call: BaresipCallID) = onEngine { Native.callSetActive(handle, call.rawValue) }

    /**
     * Sends DTMF digits from `0`–`9`, `*`, `#` and `A`–`D`.
     *
     * @param duration How long each digit is sent.
     * @param gap The pause between digits.
     */
    suspend fun sendDtmf(
        call: BaresipCallID,
        digits: String,
        duration: Duration = 160.milliseconds,
        gap: Duration = 80.milliseconds,
    ) = onEngine {
        Native.callSendDtmf(handle, call.rawValue, digits.cString(), duration.wholeMilliseconds(), gap.wholeMilliseconds())
    }

    /** Transfers a call to another party without consulting them first (blind transfer). */
    suspend fun blindTransfer(
        call: BaresipCallID,
        targetUri: String,
    ) = onEngine { Native.callTransfer(handle, call.rawValue, targetUri.cString()) }

    /**
     * Connects the remote party of [call] to the party of [consultationCall] and leaves both calls
     * (attended transfer, REFER with Replaces).
     */
    suspend fun attendedTransfer(
        call: BaresipCallID,
        consultationCall: BaresipCallID,
    ) = onEngine { Native.callTransferAttended(handle, call.rawValue, consultationCall.rawValue) }

    /** A snapshot of a call. */
    suspend fun callInfo(call: BaresipCallID): BaresipCallInfo =
        onEngine {
            val numbers = LongArray(EventDecoder.CALL_INFO_LONGS)
            val strings = Native.callInfo(handle, call.rawValue, numbers)
            EventDecoder.callInfo(numbers, strings)
        }

    /**
     * A header of the INVITE that started an incoming call, such as `X-Device-ID`. Only headers
     * named in [BaresipAccountConfiguration.incomingHeaders] are kept.
     *
     * @return The header value, or `null` when the INVITE had no such header.
     */
    suspend fun incomingHeader(
        name: String,
        call: BaresipCallID,
    ): String? = onEngine { Native.callHeader(handle, call.rawValue, name.cString()) }

    /** The identifiers of all calls that are not released, oldest first. */
    suspend fun activeCalls(): List<BaresipCallID> = runCatching { onEngine { Native.callList(handle).map(::BaresipCallID) } }.getOrDefault(emptyList())

    /** Current media statistics for a call. */
    suspend fun callStatistics(call: BaresipCallID): BaresipCallStatistics =
        onEngine {
            val numbers = LongArray(EventDecoder.STATISTICS_LONGS)
            val strings = Native.callStatistics(handle, call.rawValue, numbers)
            EventDecoder.statistics(numbers, strings)
        }

    /** Mutes or unmutes the microphone for a call. */
    suspend fun setMicrophoneMuted(
        muted: Boolean,
        call: BaresipCallID,
    ) = onEngine { Native.callSetMicrophoneMuted(handle, call.rawValue, muted) }

    /** Changes the audio direction of a call with a re-INVITE. */
    suspend fun setAudioDirection(
        direction: BaresipMediaDirection,
        call: BaresipCallID,
    ) = onEngine { Native.callSetAudioDirection(handle, call.rawValue, direction.ordinal) }

    /** Changes the video direction of a call with a re-INVITE. */
    suspend fun setVideoDirection(
        direction: BaresipMediaDirection,
        call: BaresipCallID,
    ) = onEngine { Native.callSetVideoDirection(handle, call.rawValue, direction.ordinal) }

    /**
     * Turns sending your camera on or off for a call. Only sending changes: with `false` the
     * direction becomes receive-only, so you keep seeing the other side.
     */
    suspend fun setVideoEnabled(
        enabled: Boolean,
        call: BaresipCallID,
    ) = setVideoDirection(if (enabled) BaresipMediaDirection.SEND_RECEIVE else BaresipMediaDirection.RECEIVE_ONLY, call)

    /** Switches the camera used for a call to a device from [videoDevices]. */
    suspend fun setCamera(
        device: String,
        call: BaresipCallID,
    ) = onEngine { Native.callSetCamera(handle, call.rawValue, device.cString()) }

    /** Asks the encoder to send a keyframe. */
    suspend fun requestKeyframe(call: BaresipCallID) = onEngine { Native.callRequestKeyframe(handle, call.rawValue) }

    /** Caps the video bitrate of a call below the engine's configured bitrate, or removes the cap with `null`. */
    suspend fun setVideoMaxBitrate(
        bitsPerSecond: Int?,
        call: BaresipCallID,
    ) = onEngine { Native.callSetVideoMaxBitrate(handle, call.rawValue, (bitsPerSecond ?: 0).coerceAtLeast(0)) }

    /** Restarts ICE for a call, for example after the network changed. */
    suspend fun restartIce(call: BaresipCallID) = onEngine { Native.callRestartIce(handle, call.rawValue) }

    /**
     * Starts recording a call to a 16-bit stereo WAV file: the left channel is the microphone and
     * the right channel the remote party. An existing file is replaced. Check local law before
     * recording calls.
     */
    suspend fun startRecording(
        call: BaresipCallID,
        file: File,
    ) = onEngine { Native.callRecordStart(handle, call.rawValue, file.path.cString()) }

    /** Stops recording and completes the file. */
    suspend fun stopRecording(call: BaresipCallID) = onEngine { Native.callRecordStop(handle, call.rawValue) }

    /**
     * Sends a text message as a SIP MESSAGE (RFC 3428). The result arrives later as
     * [BaresipEvent.MessageStatus] with the returned identifier.
     *
     * @param account The account to send from, or `null` for the default account.
     */
    suspend fun sendMessage(
        peerUri: String,
        text: String,
        account: BaresipAccountID? = null,
    ): BaresipMessageID = BaresipMessageID(onEngine { Native.messageSend(handle, account?.rawValue ?: 0, peerUri.cString(), text.cString()) })

    /** The names of the cameras the video source offers. */
    suspend fun videoDevices(): List<String> =
        runCatching { onEngine { Native.videoDevices(handle).split('\n').filter { it.isNotEmpty() } } }
            .getOrDefault(emptyList())

    /**
     * Attaches a renderer to a call's remote or local video, or detaches it with `null`. The
     * engine keeps the renderer until it is replaced, detached or the call is released.
     *
     * @param local `true` for the camera image sent to the peer, `false` for the remote video.
     */
    suspend fun setVideoRenderer(
        renderer: BaresipVideoRenderer?,
        call: BaresipCallID,
        local: Boolean = false,
    ) = replaceSink(VideoSinkKey(call, local), renderer?.let(::VideoSinkBox)) { box ->
        Native.callSetVideoSink(handle, call.rawValue, local, box?.pointer ?: 0)
    }

    /**
     * Starts the camera outside a call and sends its frames to a renderer.
     *
     * @param device A device name from [videoDevices], or `null` for the default camera.
     */
    suspend fun startVideoPreview(
        device: String? = null,
        renderer: BaresipVideoRenderer,
    ) = replaceSink(VideoSinkKey(null, true), VideoSinkBox(renderer)) { box ->
        Native.videoPreviewStart(handle, device.cStringOrNull(), box?.pointer ?: 0)
    }

    /** Stops the camera preview. */
    suspend fun stopVideoPreview() {
        onEngine { Native.videoPreviewStop(handle) }
        synchronized(videoSinks) { videoSinks.remove(VideoSinkKey(null, true)) }?.release()
    }

    /** Switches the camera used for a call to the front or back camera. */
    suspend fun setCamera(
        position: BaresipCameraPosition,
        call: BaresipCallID,
    ) = setCamera(position.deviceName, call)

    private suspend fun replaceSink(
        key: VideoSinkKey,
        box: VideoSinkBox?,
        install: (VideoSinkBox?) -> Unit,
    ) {
        try {
            onEngine { install(box) }
        } catch (error: Throwable) {
            box?.release()
            throw error
        }
        val previous = synchronized(videoSinks) { if (box == null) videoSinks.remove(key) else videoSinks.put(key, box) }
        previous?.release()
    }

    private fun clearVideoSinks(call: BaresipCallID) {
        val removed =
            synchronized(videoSinks) {
                listOfNotNull(videoSinks.remove(VideoSinkKey(call, true)), videoSinks.remove(VideoSinkKey(call, false)))
            }
        removed.forEach { it.release() }
    }

    /**
     * Stops and frees the engine. Pending operations fail with [BaresipError.Code.INVALID_STATE];
     * [events] receives nothing more.
     */
    override fun close() {
        if (!closed.compareAndSet(false, true)) return
        executor.execute {
            Native.engineDestroy(handle)
            synchronized(videoSinks) { videoSinks.values.toList().also { videoSinks.clear() } }.forEach { it.release() }
        }
        executor.shutdown()
        if (Thread.currentThread().name != THREAD_NAME) {
            executor.awaitTermination(CLOSE_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        }
    }

    internal fun deliver(event: BaresipEvent) {
        if (event is BaresipEvent.Call && event.state == BaresipCallState.RELEASED) clearVideoSinks(event.call)
        eventFlow.tryEmit(event)
    }

    internal fun deliverLog(entry: BaresipLogEntry) {
        logHandler?.log(entry)
    }

    private suspend fun <T> onEngine(body: () -> T): T {
        if (closed.get()) throw BaresipError(BaresipError.Code.INVALID_STATE, detail = "engine is closed")
        return try {
            withContext(dispatcher) {
                if (closed.get()) throw BaresipError(BaresipError.Code.INVALID_STATE, detail = "engine is closed")
                body()
            }
        } catch (error: java.util.concurrent.RejectedExecutionException) {
            throw BaresipError(BaresipError.Code.INVALID_STATE, detail = "engine is closed")
        }
    }

    companion object {
        private const val THREAD_NAME = "baresipkit.engine"
        private const val CLOSE_TIMEOUT_SECONDS = 10L
        private const val MAXIMUM_SIP_STATUS = 699

        /** The C ABI version of the linked core. */
        val abiVersion: AbiVersion
            get() = Native.abiVersion().let { AbiVersion(it ushr 16, it and 0xffff) }

        /** Feature flags of the linked core, for example `reg.contact-params`. */
        val capabilities: List<String>
            get() = Native.capabilities().split(' ').filter { it.isNotEmpty() }

        /** The version string of the linked core. */
        val coreVersion: String
            get() = Native.version()

        /**
         * Encodes contact parameters exactly as they will appear in the `Contact` header, for
         * example `;pn-provider=fcm;pn-prid=…`.
         *
         * @throws BaresipError with [BaresipError.Code.INVALID_ARGUMENT] when a name or value is
         *   not a valid SIP token.
         */
        fun encodeContactParameters(parameters: List<BaresipContactParameter>): String = Native.encodeContactParameters(parameters.names(), parameters.values())
    }

    /** The C ABI version of the core, as a major and a minor number. */
    data class AbiVersion(
        val major: Int,
        val minor: Int,
    )
}
