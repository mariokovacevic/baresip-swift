package io.github.mariokovacevic.baresipkit.telecom

import android.content.Context
import android.net.Uri
import android.os.SystemClock
import android.telecom.DisconnectCause
import androidx.core.telecom.CallAttributesCompat
import androidx.core.telecom.CallControlScope
import androidx.core.telecom.CallEndpointCompat
import androidx.core.telecom.CallsManager
import io.github.mariokovacevic.baresipkit.BaresipCallController
import io.github.mariokovacevic.baresipkit.BaresipCallEndReason
import io.github.mariokovacevic.baresipkit.BaresipCallID
import io.github.mariokovacevic.baresipkit.BaresipCallInfo
import io.github.mariokovacevic.baresipkit.BaresipCallState
import io.github.mariokovacevic.baresipkit.BaresipEngine
import io.github.mariokovacevic.baresipkit.BaresipError
import io.github.mariokovacevic.baresipkit.BaresipEvent
import io.github.mariokovacevic.baresipkit.BaresipHandleStyle
import io.github.mariokovacevic.baresipkit.SipIdentity
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CopyOnWriteArrayList
import kotlin.time.Duration
import kotlin.time.Duration.Companion.seconds

/** Settings for [BaresipTelecomAdapter]. */
data class BaresipTelecomConfiguration(
    /** Whether calls may have video. */
    val supportsVideo: Boolean = true,
    /** How long a call reported from a push waits for its INVITE before it is ended. */
    val pushInviteTimeout: Duration = 30.seconds,
    /** Whether answering a video call sends your camera. The caller's video is received either way. */
    val sendsCameraOnAnswer: Boolean = true,
    /**
     * Whether a call reported from a push that names no caller is bound to the next INVITE,
     * whoever sends it. Use `false` when every push carries the caller's SIP URI.
     */
    val matchesPushWithoutCaller: Boolean = true,
    /**
     * The name of an INVITE header that carries the UUID of the call, the one the server also puts
     * in the push. A call reported from a push with a UUID is then bound to the INVITE with the
     * same UUID and to no other.
     */
    val callUuidHeader: String? = null,
    /** How callers are identified to the system. */
    val handleStyle: BaresipHandleStyle = BaresipHandleStyle.SIP_URI,
    /**
     * How long an action waits for Telecom before it fails with
     * [BaresipTelecomException.Reason.ACTION_TIMED_OUT]. A call whose start times out is given up:
     * if Telecom adds it later, it is disconnected at once.
     */
    val actionTimeout: Duration = 10.seconds,
)

/**
 * A call the adapter added to Telecom, passed to the app to show its incoming call screen or
 * notification. With a self-managed call the app shows the incoming call itself, usually as a
 * `CallStyle` notification with a full-screen intent.
 */
class BaresipTelecomCall internal constructor(
    /** The Telecom identifier of the call. */
    val uuid: UUID,
    /** The caller or callee as shown to the system. */
    val remoteUri: String,
    /** The name to show, if known. */
    val displayName: String?,
    /** Whether the call is a video call. */
    val hasVideo: Boolean,
    /** Whether this device placed the call. */
    val isOutgoing: Boolean,
) {
    internal val engineCall = MutableStateFlow<BaresipCallID?>(null)
    internal val endpoint = MutableStateFlow<CallEndpointCompat?>(null)
    internal val endpoints = MutableStateFlow<List<CallEndpointCompat>>(emptyList())
    internal val muted = MutableStateFlow(false)
    internal val ready = CompletableDeferred<CallControlScope>()

    /** The engine call, once the INVITE arrived or the engine placed the call. */
    val call: StateFlow<BaresipCallID?> get() = engineCall.asStateFlow()

    /** The audio output Telecom routes the call to. */
    val currentEndpoint: StateFlow<CallEndpointCompat?> get() = endpoint.asStateFlow()

    /** The audio outputs the call can use. */
    val availableEndpoints: StateFlow<List<CallEndpointCompat>> get() = endpoints.asStateFlow()

    /** Whether the system muted the call's microphone. */
    val isMuted: StateFlow<Boolean> get() = muted.asStateFlow()

    /** Asks Telecom to route the call's audio to [endpoint], one of [availableEndpoints]. */
    suspend fun requestEndpoint(endpoint: CallEndpointCompat) {
        ready.await().requestEndpointChange(endpoint)
    }
}

/**
 * Connects a [BaresipEngine] to Telecom through Jetpack's `CallsManager`, the counterpart of the
 * iOS CallKit and LiveCommunicationKit adapters.
 *
 * The adapter adds incoming and outgoing calls to Telecom as self-managed calls, so the system
 * knows about them (Bluetooth buttons, car kits, wearables, other calls), and carries out the
 * system's actions (answer, end, hold) on the engine. Calls announced by a push are matched to
 * the INVITE that follows by the UUID in [BaresipTelecomConfiguration.callUuidHeader] or by the
 * caller's SIP URI, exactly as on iOS. The app shows the incoming call screen itself when
 * [onIncomingCall] is called.
 *
 * Declare the `MANAGE_OWN_CALLS` permission (merged from core-telecom) and, for incoming calls
 * while the app is in the background, a foreground service of type `phoneCall`.
 *
 * ```kotlin
 * val telecom = BaresipTelecomAdapter(context, engine) { call -> showIncomingCallNotification(call) }
 * val id = telecom.placeCall("sip:bob@example.com", video = false)
 * ```
 */
class BaresipTelecomAdapter(
    context: Context,
    /** The engine whose calls are shown to Telecom. */
    val engine: BaresipEngine,
    /** The adapter's settings. */
    val configuration: BaresipTelecomConfiguration = BaresipTelecomConfiguration(),
    private val onIncomingCall: (BaresipTelecomCall) -> Unit = {},
) : BaresipCallController {
    private val callsManager = CallsManager(context.applicationContext)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val mutex = Mutex()
    private val ledger = PushCallLedger(configuration.matchesPushWithoutCaller)
    private val calls = ConcurrentHashMap<UUID, BaresipTelecomCall>()
    private val callByEngine = ConcurrentHashMap<BaresipCallID, UUID>()
    private val pendingAnswers = mutableSetOf<UUID>()
    private val answerVideo = mutableMapOf<UUID, Boolean>()
    private val muteObservers = CopyOnWriteArrayList<(BaresipCallID, Boolean) -> Unit>()

    init {
        val capabilities =
            if (configuration.supportsVideo) {
                CallsManager.CAPABILITY_BASELINE or CallsManager.CAPABILITY_SUPPORTS_VIDEO_CALLING
            } else {
                CallsManager.CAPABILITY_BASELINE
            }
        callsManager.registerAppWithTelecom(capabilities)
        scope.launch { engine.events.collect { handle(it) } }
    }

    /** Stops following the engine. Calls Telecom still shows end with the engine's calls. */
    fun close() {
        scope.cancel()
    }

    /** The Telecom call of an engine call, if Telecom knows it. */
    fun telecomCall(call: BaresipCallID): BaresipTelecomCall? = callByEngine[call]?.let { calls[it] }

    override fun controls(call: BaresipCallID): Boolean = callByEngine.containsKey(call)

    override fun addMuteObserver(observer: (BaresipCallID, Boolean) -> Unit) {
        muteObservers += observer
    }

    /**
     * Adds a call announced by a push to Telecom before its INVITE arrives.
     *
     * The INVITE that follows is bound to the oldest pushed call it matches: by the UUID when the
     * push and the INVITE carry one, otherwise by the caller. If the user answered first, the call
     * is answered as soon as the INVITE arrives; the camera is sent only when [hasVideo] was
     * `true`. If the user declined, the INVITE is rejected with 486 Busy Here. If no INVITE arrives
     * within [BaresipTelecomConfiguration.pushInviteTimeout], the call ends. A push for a call that
     * already rings is ignored.
     *
     * @param uuid The call's UUID from the push, or `null` when it has none.
     * @param remoteUri The caller's SIP URI from the push, if known.
     * @param displayName The caller's name to show.
     * @return The call added to Telecom, or `null` for a repeated push.
     */
    suspend fun reportIncomingCallFromPush(
        uuid: UUID?,
        remoteUri: String?,
        displayName: String?,
        hasVideo: Boolean,
    ): BaresipTelecomCall? {
        val id = uuid ?: UUID.randomUUID()
        val announcement = PushCallLedger.Announcement(id, remoteUri, hasVideo, uuid != null)
        val call =
            mutex.withLock {
                if (calls.containsKey(id) || ledger.knows(id) || ledger.duplicatesRingingCall(remoteUri, uuid != null)) {
                    return null
                }
                ledger.add(announcement, now())
                BaresipTelecomCall(id, remoteUri ?: "unknown", displayName, hasVideo, false).also { calls[id] = it }
            }
        addToTelecom(call, CallAttributesCompat.DIRECTION_INCOMING)
        scope.launch {
            delay(configuration.pushInviteTimeout)
            expirePushCall(id)
        }
        return call
    }

    override suspend fun placeCall(
        destination: String,
        video: Boolean,
    ): BaresipCallID {
        val call = BaresipTelecomCall(UUID.randomUUID(), destination, null, video, true)
        mutex.withLock { calls[call.uuid] = call }
        addToTelecom(call, CallAttributesCompat.DIRECTION_OUTGOING)
        try {
            TelecomActions.ready(call.ready, configuration.actionTimeout, "addCall")
        } catch (error: BaresipTelecomException) {
            call.ready.cancel()
            forget(call.uuid)
            throw error
        }
        val id =
            try {
                engine.makeCall(destination = destination, video = video)
            } catch (error: Throwable) {
                call.ready.await().disconnect(DisconnectCause(DisconnectCause.ERROR))
                forget(call.uuid)
                throw error
            }
        mutex.withLock { bind(id, call) }
        return id
    }

    override suspend fun answer(
        call: BaresipCallID,
        video: Boolean,
    ) {
        val telecom = telecomCall(call) ?: throw unknown(call)
        val control = TelecomActions.ready(telecom.ready, configuration.actionTimeout, "answer")
        val type = if (video) CallAttributesCompat.CALL_TYPE_VIDEO_CALL else CallAttributesCompat.CALL_TYPE_AUDIO_CALL
        TelecomActions.perform(configuration.actionTimeout, "answer") { control.answer(type) }
        engine.answer(call, video = video)
        engine.audioSessionDidActivate()
    }

    override suspend fun end(call: BaresipCallID) {
        val telecom = telecomCall(call)
        if (telecom == null) {
            try {
                engine.hangup(call)
            } catch (error: BaresipError) {
                if (error.code != BaresipError.Code.NOT_FOUND) throw error
            }
            return
        }
        engine.hangup(call)
        val control = TelecomActions.ready(telecom.ready, configuration.actionTimeout, "disconnect")
        TelecomActions.perform(configuration.actionTimeout, "disconnect") { control.disconnect(DisconnectCause(DisconnectCause.LOCAL)) }
    }

    override suspend fun setOnHold(
        onHold: Boolean,
        call: BaresipCallID,
    ) {
        val telecom = telecomCall(call) ?: throw unknown(call)
        val control = TelecomActions.ready(telecom.ready, configuration.actionTimeout, if (onHold) "setInactive" else "setActive")
        if (onHold) {
            engine.hold(call)
            TelecomActions.perform(configuration.actionTimeout, "setInactive") { control.setInactive() }
        } else {
            TelecomActions.perform(configuration.actionTimeout, "setActive") { control.setActive() }
            engine.resume(call)
        }
    }

    override suspend fun setMuted(
        muted: Boolean,
        call: BaresipCallID,
    ) {
        if (!controls(call)) throw unknown(call)
        engine.setMicrophoneMuted(muted, call)
        muteObservers.forEach { it(call, muted) }
    }

    private fun addToTelecom(
        call: BaresipTelecomCall,
        direction: Int,
    ) {
        val attributes =
            CallAttributesCompat(
                displayName = call.displayName ?: call.remoteUri,
                address = address(call.remoteUri),
                direction = direction,
                callType = if (call.hasVideo) CallAttributesCompat.CALL_TYPE_VIDEO_CALL else CallAttributesCompat.CALL_TYPE_AUDIO_CALL,
                callCapabilities = CallAttributesCompat.SUPPORTS_SET_INACTIVE,
            )
        scope.launch {
            try {
                callsManager.addCall(
                    attributes,
                    onAnswer = { type -> systemAnswered(call, type == CallAttributesCompat.CALL_TYPE_VIDEO_CALL) },
                    onDisconnect = { systemEnded(call) },
                    onSetActive = { call.engineCall.value?.let { runCatching { engine.resume(it) } } },
                    onSetInactive = { call.engineCall.value?.let { runCatching { engine.hold(it) } } },
                ) {
                    if (!call.ready.complete(this)) {
                        launch { disconnect(DisconnectCause(DisconnectCause.CANCELED)) }
                        return@addCall
                    }
                    launch { currentCallEndpoint.collect { call.endpoint.value = it } }
                    launch { availableEndpoints.collect { call.endpoints.value = it } }
                    launch { isMuted.collect { muted -> systemMuted(call, muted) } }
                    if (direction == CallAttributesCompat.DIRECTION_INCOMING) onIncomingCall(call)
                }
            } catch (error: Throwable) {
                call.ready.completeExceptionally(error)
                refused(call)
            }
        }
    }

    private suspend fun systemAnswered(
        call: BaresipTelecomCall,
        video: Boolean,
    ) {
        val engineCall =
            mutex.withLock {
                val bound = call.engineCall.value
                if (bound == null) {
                    pendingAnswers += call.uuid
                    answerVideo[call.uuid] = video
                }
                bound
            } ?: return
        val hasVideo = runCatching { engine.callInfo(engineCall).hasVideo }.getOrDefault(false)
        val sends = mutex.withLock { answerVideo.remove(call.uuid) } ?: (video && hasVideo && configuration.sendsCameraOnAnswer)
        runCatching { engine.answer(engineCall, video = sends) }
        engine.audioSessionDidActivate()
    }

    private suspend fun systemEnded(call: BaresipTelecomCall) {
        val engineCall =
            mutex.withLock {
                pendingAnswers -= call.uuid
                ledger.decline(call.uuid, now() + configuration.pushInviteTimeout.inWholeMilliseconds)
                call.engineCall.value
            }
        engineCall?.let { runCatching { engine.hangup(it) } }
    }

    private fun systemMuted(
        call: BaresipTelecomCall,
        muted: Boolean,
    ) {
        call.muted.value = muted
        val engineCall = call.engineCall.value ?: return
        scope.launch {
            if (runCatching { engine.setMicrophoneMuted(muted, engineCall) }.isSuccess) {
                muteObservers.forEach { it(engineCall, muted) }
            }
        }
    }

    private suspend fun handle(event: BaresipEvent) {
        when (event) {
            is BaresipEvent.IncomingCall -> incoming(event.info)
            is BaresipEvent.Call -> state(event.call, event.state, event.error)
            else -> Unit
        }
    }

    private suspend fun incoming(info: BaresipCallInfo) {
        val headerUuid =
            configuration.callUuidHeader?.let { header ->
                runCatching { engine.incomingHeader(header, info.id) }.getOrNull()?.trim()?.let {
                    runCatching { UUID.fromString(it) }.getOrNull()
                }
            }
        val (resolution, call) =
            mutex.withLock {
                val resolution = ledger.resolve(info.remoteUri, headerUuid, now())
                val call =
                    when (resolution) {
                        is PushCallLedger.Resolution.Announced -> calls[resolution.announcement.uuid]?.also { bind(info.id, it) }
                        PushCallLedger.Resolution.Declined -> null
                        PushCallLedger.Resolution.Unannounced -> {
                            val id = headerUuid?.takeIf { !calls.containsKey(it) && !ledger.knows(it) } ?: UUID.randomUUID()
                            val name = PushCallLedger.callerName(info.remoteUri, info.remoteDisplayName, true)
                            BaresipTelecomCall(id, info.remoteUri, name, info.hasVideo, false).also {
                                calls[id] = it
                                bind(info.id, it)
                            }
                        }
                    }
                ledger.startedRinging(info.id, info.remoteUri, headerUuid)
                resolution to call
            }
        when (resolution) {
            PushCallLedger.Resolution.Declined -> runCatching { engine.reject(info.id, BUSY) }
            PushCallLedger.Resolution.Unannounced -> call?.let { addToTelecom(it, CallAttributesCompat.DIRECTION_INCOMING) }
            is PushCallLedger.Resolution.Announced -> {
                val answerNow = mutex.withLock { pendingAnswers.remove(resolution.announcement.uuid) }
                if (answerNow) {
                    val video =
                        PushCallLedger.sendsCamera(resolution.announcement.hasVideo, info.hasVideo, configuration.sendsCameraOnAnswer)
                    try {
                        engine.answer(info.id, video = video)
                        engine.audioSessionDidActivate()
                    } catch (_: Throwable) {
                        call?.ready?.await()?.disconnect(DisconnectCause(DisconnectCause.ERROR))
                        runCatching { engine.hangup(info.id) }
                    }
                }
            }
        }
    }

    private suspend fun state(
        id: BaresipCallID,
        state: BaresipCallState,
        error: BaresipError?,
    ) {
        val call =
            mutex.withLock {
                if (state != BaresipCallState.INCOMING && state != BaresipCallState.EARLY_MEDIA) ledger.stoppedRinging(id)
                callByEngine[id]?.let { calls[it] }
            } ?: return
        when (state) {
            BaresipCallState.CONNECTED, BaresipCallState.STREAMS_RUNNING ->
                if (call.isOutgoing) {
                    call.ready.await().setActive()
                    engine.audioSessionDidActivate()
                }
            BaresipCallState.ENDED, BaresipCallState.FAILED -> {
                runCatching { call.ready.await().disconnect(disconnectCause(error)) }
                forget(call.uuid)
                if (mutex.withLock { calls.isEmpty() }) engine.audioSessionDidDeactivate()
            }
            BaresipCallState.RELEASED -> forget(call.uuid)
            else -> Unit
        }
    }

    private suspend fun expirePushCall(uuid: UUID) {
        val call =
            mutex.withLock {
                if (!ledger.discard(uuid)) return
                pendingAnswers -= uuid
                calls.remove(uuid)
            } ?: return
        runCatching { call.ready.await().disconnect(DisconnectCause(DisconnectCause.MISSED)) }
    }

    private suspend fun refused(call: BaresipTelecomCall) {
        val orphan =
            mutex.withLock {
                ledger.discard(call.uuid)
                pendingAnswers -= call.uuid
                calls.remove(call.uuid)
                call.engineCall.value?.also { callByEngine.remove(it) }
            }
        orphan?.let { runCatching { engine.reject(it, BUSY) } }
    }

    private fun bind(
        id: BaresipCallID,
        call: BaresipTelecomCall,
    ) {
        callByEngine[id] = call.uuid
        call.engineCall.value = id
    }

    private suspend fun forget(uuid: UUID) {
        mutex.withLock {
            val call = calls.remove(uuid)
            call?.engineCall?.value?.let { callByEngine.remove(it) }
            pendingAnswers -= uuid
            answerVideo.remove(uuid)
        }
    }

    private fun address(remoteUri: String): Uri {
        if (configuration.handleStyle == BaresipHandleStyle.PHONE_NUMBER_WHEN_NUMERIC) {
            SipIdentity(remoteUri).phoneNumber?.let { return Uri.fromParts("tel", it, null) }
        }
        return Uri.parse(if (remoteUri.contains(':')) remoteUri else "sip:$remoteUri")
    }

    private fun unknown(call: BaresipCallID) = BaresipError(BaresipError.Code.NOT_FOUND, detail = "Telecom does not know $call")

    private fun now(): Long = SystemClock.elapsedRealtime()

    internal companion object {
        const val BUSY = 486
        const val DECLINE = 600

        fun disconnectCode(error: BaresipError?): Int {
            if (error == null) return DisconnectCause.REMOTE
            return when (error.endReason) {
                BaresipCallEndReason.ANSWERED_ELSEWHERE -> DisconnectCause.ANSWERED_ELSEWHERE
                BaresipCallEndReason.DECLINED_ELSEWHERE -> DisconnectCause.REJECTED
                null ->
                    when (error.sipStatus) {
                        BUSY -> DisconnectCause.BUSY
                        DECLINE, 603 -> DisconnectCause.REJECTED
                        else -> DisconnectCause.ERROR
                    }
            }
        }

        fun disconnectCause(error: BaresipError?): DisconnectCause = DisconnectCause(disconnectCode(error))
    }
}
