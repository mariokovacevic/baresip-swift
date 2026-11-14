package io.github.mariokovacevic.baresipkit.compose

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import io.github.mariokovacevic.baresipkit.BaresipCallController
import io.github.mariokovacevic.baresipkit.BaresipCallID
import io.github.mariokovacevic.baresipkit.BaresipCallInfo
import io.github.mariokovacevic.baresipkit.BaresipCallState
import io.github.mariokovacevic.baresipkit.BaresipCameraPosition
import io.github.mariokovacevic.baresipkit.BaresipEngine
import io.github.mariokovacevic.baresipkit.BaresipError
import io.github.mariokovacevic.baresipkit.BaresipMediaDirection
import io.github.mariokovacevic.baresipkit.SipIdentity
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull
import java.util.concurrent.CopyOnWriteArraySet
import kotlin.time.Duration
import kotlin.time.Duration.Companion.seconds
import kotlin.time.TimeMark
import kotlin.time.TimeSource

/** The other side's answer to DTMF sent with [BaresipPhoneCall.sendDtmf] and a reply digit. */
sealed interface BaresipDtmfReply {
    /** The expected digit arrived. */
    data object Confirmed : BaresipDtmfReply

    /**
     * Another digit arrived first.
     *
     * Constructors, `copy` and component functions of this type are not covered by Semantic Versioning; read its properties.
     */
    data class Other(
        val digit: Char,
    ) : BaresipDtmfReply

    /** No digit arrived in time. */
    data object NoReply : BaresipDtmfReply
}

/**
 * One call as observable Compose state, with the actions a call screen needs.
 *
 * [BaresipPhone] creates the calls and keeps their state current. The actions go through the
 * phone's call controller when it controls the call, such as Telecom, and to the engine
 * otherwise.
 */
class BaresipPhoneCall internal constructor(
    /** The call's identifier. */
    val id: BaresipCallID,
    state: BaresipCallState,
    /** The engine of the call. */
    val engine: BaresipEngine,
) {
    /** When the phone first saw the call. */
    val startedAt: TimeMark = TimeSource.Monotonic.markNow()

    /** The call's state. */
    var state: BaresipCallState by mutableStateOf(state)
        private set

    /** The last error of the call: why it failed, or why the other side rejected a change. */
    var error: BaresipError? by mutableStateOf(null)
        private set

    /** The other side's SIP URI. */
    var remoteUri: String by mutableStateOf("")
        private set

    /** The other side's display name, or an empty string. */
    var remoteDisplayName: String by mutableStateOf("")
        private set

    /** Whether this side placed the call. Valid when [isDirectionKnown] is `true`. */
    var isOutgoing: Boolean by mutableStateOf(false)
        private set

    /** Whether the call's direction is known yet. */
    var isDirectionKnown: Boolean by mutableStateOf(false)
        private set

    /** Whether the call has a video stream. */
    var hasVideo: Boolean by mutableStateOf(false)
        private set

    /** Whether the microphone is muted. */
    var isMuted: Boolean by mutableStateOf(false)
        private set

    /** The negotiated audio direction. */
    var audioDirection: BaresipMediaDirection by mutableStateOf(BaresipMediaDirection.INACTIVE)
        private set

    /** The negotiated video direction. */
    var videoDirection: BaresipMediaDirection by mutableStateOf(BaresipMediaDirection.INACTIVE)
        private set

    /** The audio codec in use, or an empty string. */
    var audioCodec: String by mutableStateOf("")
        private set

    /** The video codec in use, or an empty string. */
    var videoCodec: String by mutableStateOf("")
        private set

    /** When the call was first connected, or `null` before that. */
    var connectedAt: TimeMark? by mutableStateOf(null)
        private set

    /** Whether the camera is sent. */
    var isSendingVideo: Boolean by mutableStateOf(false)
        private set

    /** The camera the call sends, as last set with [setCamera]. */
    var camera: BaresipCameraPosition by mutableStateOf(
        if (engine.configuration.video.sourceDevice == BaresipCameraPosition.BACK.deviceName) {
            BaresipCameraPosition.BACK
        } else {
            BaresipCameraPosition.FRONT
        },
    )
        private set

    /** Whether an early media preview of the ringing call runs; see [startPreview]. */
    var isPreviewing: Boolean by mutableStateOf(false)
        private set

    /** The DTMF digits received from the other side, in order. */
    var receivedDtmf: String by mutableStateOf("")
        private set

    internal var phone: BaresipPhone? = null
    private var refreshGeneration = 0
    private val dtmfListeners = CopyOnWriteArraySet<Channel<Char>>()

    init {
        inferDirection(state)
        noteConnected()
    }

    /** Whether the call rings on this side and is not answered yet. */
    val isRinging: Boolean
        get() = isDirectionKnown && !isOutgoing && (state == BaresipCallState.INCOMING || state == BaresipCallState.EARLY_MEDIA)

    /** Whether the call is on hold on this side, including while it is put on hold or resumed. */
    val isOnHold: Boolean
        get() = state == BaresipCallState.PAUSING || state == BaresipCallState.PAUSED || state == BaresipCallState.RESUMING

    /** Whether the other side put the call on hold. */
    val isHeldByRemote: Boolean
        get() = state == BaresipCallState.PAUSED_BY_REMOTE

    /** Whether audio and video are flowing. */
    val isConnected: Boolean
        get() = state == BaresipCallState.CONNECTED || state == BaresipCallState.STREAMS_RUNNING || state == BaresipCallState.UPDATING

    /** Whether the other side's video reaches this side, early media included. */
    val isReceivingVideo: Boolean
        get() = videoDirection == BaresipMediaDirection.RECEIVE_ONLY || videoDirection == BaresipMediaDirection.SEND_RECEIVE

    /** The display name, or the user part of the SIP URI when there is none. */
    val displayName: String
        get() = remoteDisplayName.ifEmpty { userPart(remoteUri) }

    /** Whether a SIP address names the other side of this call, such as the sender of a SIP MESSAGE. */
    fun isPeer(address: String): Boolean = samePeer(address, remoteUri)

    /**
     * Answers an incoming call, through the phone's call controller when it controls the call.
     * A call controller answers with audio; with `audio = false` the engine answers directly.
     */
    suspend fun answer(
        video: Boolean = false,
        audio: Boolean = true,
    ) {
        val controller = controller
        if (audio && controller != null) controller.answer(id, video) else engine.answer(id, video, audio)
        isSendingVideo = video
        isPreviewing = false
        phone?.callWasAnswered(this)
    }

    /** Starts an early media preview: the caller is seen and heard, but does not see or hear this side. */
    suspend fun startPreview(
        video: Boolean = true,
        audio: Boolean = true,
    ) {
        engine.sendProgress(id, video, audio)
        isPreviewing = true
        refresh()
    }

    /** Declines an incoming call: through the call controller when it controls the call, with 486 Busy Here otherwise. */
    suspend fun reject() {
        val controller = controller
        if (controller != null) controller.end(id) else engine.reject(id)
    }

    /** Ends the call. */
    suspend fun hangUp() {
        val controller = controller
        if (controller != null) controller.end(id) else engine.hangup(id)
    }

    /**
     * Mutes or unmutes the microphone. Through a call controller, [isMuted] changes when the
     * controller reports that the microphone was muted.
     */
    suspend fun setMuted(muted: Boolean) {
        val controller = controller
        if (controller != null) {
            controller.setMuted(muted, id)
        } else {
            engine.setMicrophoneMuted(muted, id)
            applyMuted(muted)
        }
    }

    /** Puts the call on hold or resumes it. */
    suspend fun setOnHold(onHold: Boolean) {
        val controller = controller
        when {
            controller != null -> controller.setOnHold(onHold, id)
            onHold -> engine.hold(id)
            else -> engine.resume(id)
        }
    }

    /** Starts or stops sending the camera. The other side's video keeps playing either way. */
    suspend fun setVideoEnabled(enabled: Boolean) {
        val previous = isSendingVideo
        isSendingVideo = enabled
        try {
            engine.setVideoEnabled(enabled, id)
        } catch (error: Throwable) {
            isSendingVideo = previous
            throw error
        }
        refresh()
    }

    /** Sends the front or back camera. */
    suspend fun setCamera(position: BaresipCameraPosition) {
        engine.setCamera(position, id)
        camera = position
    }

    /** Switches between the front and back camera. */
    suspend fun switchCamera() = setCamera(camera.toggled)

    /** Sends DTMF digits. */
    suspend fun sendDtmf(digits: String) = engine.sendDtmf(id, digits)

    /**
     * Sends DTMF digits and waits for the other side to answer with a digit, as door stations do
     * to confirm that the door opened.
     *
     * @param reply The digit that confirms the request.
     * @param timeout How long to wait for a reply after the digits were sent.
     */
    suspend fun sendDtmf(
        digits: String,
        reply: Char,
        timeout: Duration = 5.seconds,
    ): BaresipDtmfReply = sendDtmf(digits, reply, timeout) { engine.sendDtmf(id, it) }

    internal suspend fun sendDtmf(
        digits: String,
        reply: Char,
        timeout: Duration,
        send: suspend (String) -> Unit,
    ): BaresipDtmfReply {
        val listener = Channel<Char>(Channel.UNLIMITED)
        dtmfListeners += listener
        try {
            send(digits)
            val digit = withTimeoutOrNull(timeout) { listener.receive() } ?: return BaresipDtmfReply.NoReply
            return if (digit == reply) BaresipDtmfReply.Confirmed else BaresipDtmfReply.Other(digit)
        } finally {
            dtmfListeners -= listener
            listener.close()
        }
    }

    /** Reads the call's details from the engine again. A read that a newer one overtook is dropped. */
    fun refresh() {
        val scope = phone?.scope ?: return
        val generation = ++refreshGeneration
        scope.launch {
            val info = runCatching { engine.callInfo(id) }.getOrNull() ?: return@launch
            if (generation == refreshGeneration) update(info)
        }
    }

    private val controller: BaresipCallController?
        get() = phone?.callController?.takeIf { it.controls(id) }

    internal fun update(
        state: BaresipCallState,
        error: BaresipError?,
    ) {
        this.state = state
        inferDirection(state)
        noteConnected()
        if (isConnected || state == BaresipCallState.RELEASED) isPreviewing = false
        if (error != null) this.error = error
    }

    internal fun update(info: BaresipCallInfo) {
        remoteUri = info.remoteUri
        remoteDisplayName = info.remoteDisplayName
        isOutgoing = info.isOutgoing
        isDirectionKnown = true
        hasVideo = info.hasVideo
        isMuted = info.isMicrophoneMuted
        audioDirection = info.audioDirection
        videoDirection = info.videoDirection
        audioCodec = info.audioCodec
        videoCodec = info.videoCodec
        if (isConnected) {
            isSendingVideo = info.videoDirection == BaresipMediaDirection.SEND_ONLY || info.videoDirection == BaresipMediaDirection.SEND_RECEIVE
        }
    }

    internal fun markOutgoing(
        destination: String,
        video: Boolean = false,
    ) {
        isOutgoing = true
        isDirectionKnown = true
        isSendingVideo = video
        if (remoteUri.isEmpty()) remoteUri = destination
    }

    internal fun applyMuted(muted: Boolean) {
        refreshGeneration++
        isMuted = muted
    }

    internal fun didReceiveDtmf(digit: Char) {
        receivedDtmf += digit
        dtmfListeners.forEach { it.trySend(digit) }
    }

    private fun noteConnected() {
        if (connectedAt == null && isConnected) connectedAt = TimeSource.Monotonic.markNow()
    }

    private fun inferDirection(state: BaresipCallState) {
        if (isDirectionKnown) return
        when (state) {
            BaresipCallState.INCOMING -> {
                isOutgoing = false
                isDirectionKnown = true
            }
            BaresipCallState.OUTGOING_INIT, BaresipCallState.OUTGOING_RINGING -> {
                isOutgoing = true
                isDirectionKnown = true
            }
            else -> Unit
        }
    }

    companion object {
        /** The user or number of a SIP URI, such as `alice` for `sip:alice@example.com;transport=tls`. */
        fun userPart(uri: String): String {
            var value = uri
            for (scheme in listOf("sips:", "sip:", "tel:")) {
                if (value.startsWith(scheme)) value = value.removePrefix(scheme)
            }
            value = value.substringBefore(';').substringBefore('@')
            return value.ifEmpty { uri }
        }

        /**
         * Whether two SIP addresses name the same party: the same user, compared without regard
         * to case, and the same host when both name one. Display names, the scheme, the port, URI
         * parameters and headers are ignored.
         */
        fun samePeer(
            first: String,
            second: String,
        ): Boolean {
            val one = SipIdentity(first)
            val other = SipIdentity(second)
            if (one.user.isEmpty() || one.user != other.user) return false
            return one.host.isEmpty() || other.host.isEmpty() || one.host == other.host
        }
    }
}
