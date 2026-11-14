package io.github.mariokovacevic.baresipkit

import kotlin.time.Duration

/**
 * Something that happened in the engine, delivered through [BaresipEngine.events].
 *
 * ```kotlin
 * engine.events.collect { event ->
 *     when (event) {
 *         is BaresipEvent.Registration -> println("registration: ${event.state}")
 *         is BaresipEvent.IncomingCall -> engine.answer(event.info.id)
 *         else -> Unit
 *     }
 * }
 * ```
 *
 * New entries can be added in a minor release; give a `when` over it an `else` branch. See
 * [Stability](https://github.com/mariokovacevic/baresipkit/blob/main/Docs/STABILITY.md).
 */
sealed interface BaresipEvent {
    /**
     * The engine changed state, with the error that caused a failure.
     *
     * Constructors, `copy` and component functions of this type are not covered by Semantic Versioning; read its properties.
     */
    data class Engine(
        val state: BaresipEngineState,
        val error: BaresipError?,
    ) : BaresipEvent

    /**
     * An account's registration changed; [expires] is the granted lifetime when registered.
     *
     * Constructors, `copy` and component functions of this type are not covered by Semantic Versioning; read its properties.
     */
    data class Registration(
        val account: BaresipAccountID,
        val state: BaresipRegistrationState,
        val expires: Duration?,
        val error: BaresipError?,
    ) : BaresipEvent

    /**
     * A call is ringing; [earlyVideo] is `true` when the caller offers video before answering.
     *
     * Constructors, `copy` and component functions of this type are not covered by Semantic Versioning; read its properties.
     */
    data class IncomingCall(
        val info: BaresipCallInfo,
        val earlyVideo: Boolean,
    ) : BaresipEvent

    /**
     * A call changed state. The error is set for [BaresipCallState.FAILED], and when the other
     * side rejected a hold, resume or direction change and the call returned to its previous
     * state.
     *
     * Constructors, `copy` and component functions of this type are not covered by Semantic Versioning; read its properties.
     */
    data class Call(
        val call: BaresipCallID,
        val state: BaresipCallState,
        val error: BaresipError?,
    ) : BaresipEvent

    /**
     * A call's media changed.
     *
     * Constructors, `copy` and component functions of this type are not covered by Semantic Versioning; read its properties.
     */
    data class Media(
        val call: BaresipCallID,
        val info: BaresipMediaEventInfo,
    ) : BaresipEvent

    /**
     * A DTMF digit arrived.
     *
     * Constructors, `copy` and component functions of this type are not covered by Semantic Versioning; read its properties.
     */
    data class Dtmf(
        val call: BaresipCallID,
        val dtmf: BaresipDtmfEvent,
    ) : BaresipEvent

    /**
     * A transfer made progress.
     *
     * Constructors, `copy` and component functions of this type are not covered by Semantic Versioning; read its properties.
     */
    data class Transfer(
        val call: BaresipCallID,
        val transfer: BaresipTransferEvent,
    ) : BaresipEvent

    /**
     * Periodic media statistics for a call.
     *
     * Constructors, `copy` and component functions of this type are not covered by Semantic Versioning; read its properties.
     */
    data class Statistics(
        val call: BaresipCallID,
        val statistics: BaresipCallStatistics,
    ) : BaresipEvent

    /**
     * A call's ICE state changed.
     *
     * Constructors, `copy` and component functions of this type are not covered by Semantic Versioning; read its properties.
     */
    data class Ice(
        val call: BaresipCallID,
        val ice: BaresipIceEvent,
    ) : BaresipEvent

    /**
     * The engine handled a network change.
     *
     * Constructors, `copy` and component functions of this type are not covered by Semantic Versioning; read its properties.
     */
    data class Network(
        val network: BaresipNetworkEvent,
    ) : BaresipEvent

    /**
     * Audio input or output started or stopped, for a call or for the engine.
     *
     * Constructors, `copy` and component functions of this type are not covered by Semantic Versioning; read its properties.
     */
    data class Audio(
        val call: BaresipCallID?,
        val audio: BaresipAudioEvent,
    ) : BaresipEvent

    /**
     * A diagnostic condition outside a call.
     *
     * Constructors, `copy` and component functions of this type are not covered by Semantic Versioning; read its properties.
     */
    data class Diagnostic(
        val diagnostic: BaresipDiagnosticEvent,
    ) : BaresipEvent

    /**
     * A SIP MESSAGE arrived.
     *
     * Constructors, `copy` and component functions of this type are not covered by Semantic Versioning; read its properties.
     */
    data class Message(
        val message: BaresipMessage,
    ) : BaresipEvent

    /**
     * A sent SIP MESSAGE was answered or failed.
     *
     * Constructors, `copy` and component functions of this type are not covered by Semantic Versioning; read its properties.
     */
    data class MessageStatus(
        val status: BaresipMessageStatus,
    ) : BaresipEvent
}

/**
 * A change of a call's media.
 *
 * New entries can be added in a minor release; give a `when` over it an `else` branch. See
 * [Stability](https://github.com/mariokovacevic/baresipkit/blob/main/Docs/STABILITY.md).
 */
enum class BaresipMediaEvent(
    internal val code: Int,
) {
    /** Audio started flowing. */
    AUDIO_STARTED(0),

    /** The other side put the call on hold. */
    REMOTE_HOLD(4),

    /** The other side resumed the call. */
    REMOTE_RESUME(5),

    /** SRTP keys were agreed; the detail names the method. */
    ENCRYPTION_ESTABLISHED(6),

    /** The peer asked for a new video keyframe. */
    KEYFRAME_REQUESTED(8),

    /** The caller's video can be shown before the call is answered. */
    EARLY_VIDEO_AVAILABLE(9),

    /** Recording started. */
    RECORDING_STARTED(10),

    /** Recording stopped. */
    RECORDING_STOPPED(11),
    ;

    internal companion object {
        fun of(code: Int): BaresipMediaEvent? = entries.firstOrNull { it.code == code }
    }
}

/**
 * A media change with the negotiated directions at that moment.
 *
 * Constructors, `copy` and component functions of this type are not covered by Semantic Versioning; read its properties.
 */
data class BaresipMediaEventInfo(
    /** What changed, or `null` for a change this version does not know. */
    val event: BaresipMediaEvent?,
    /** The audio direction. */
    val audioDirection: BaresipMediaDirection,
    /** The video direction. */
    val videoDirection: BaresipMediaDirection,
    /** Extra detail, for example the encryption method. */
    val detail: String,
)

/**
 * A DTMF digit received in a call.
 *
 * Constructors, `copy` and component functions of this type are not covered by Semantic Versioning; read its properties.
 */
data class BaresipDtmfEvent(
    /** The digit: `0`–`9`, `*`, `#` or `A`–`D`. */
    val digit: Char,
    /** `true` when the digit ended. */
    val isEnd: Boolean,
    /** `true` when the digit came as SIP INFO rather than as an RTP event. */
    val viaSipInfo: Boolean,
)

/**
 * Progress of a transfer.
 *
 * Constructors, `copy` and component functions of this type are not covered by Semantic Versioning; read its properties.
 */
data class BaresipTransferEvent(
    /** `true` when the transfer failed. */
    val failed: Boolean,
    /** The SIP status the transfer target answered with, if known. */
    val sipStatus: Int?,
    /** The transfer target. */
    val targetUri: String,
)

/**
 * The ICE state of a call with the selected candidates.
 *
 * Constructors, `copy` and component functions of this type are not covered by Semantic Versioning; read its properties.
 */
data class BaresipIceEvent(
    /** The ICE state. */
    val state: BaresipIceState,
    /** The type of the local candidate in use. */
    val localCandidate: BaresipCandidateType,
    /** The type of the remote candidate in use. */
    val remoteCandidate: BaresipCandidateType,
    /** The local address in use. */
    val localAddress: String,
    /** The remote address in use. */
    val remoteAddress: String,
)

/**
 * The engine handled a network change.
 *
 * Constructors, `copy` and component functions of this type are not covered by Semantic Versioning; read its properties.
 */
data class BaresipNetworkEvent(
    /** `true` when the SIP transports were opened again. */
    val transportsReset: Boolean,
    /** The local address in use after the change. */
    val localAddress: String,
)

/**
 * Audio input or output started or stopped.
 *
 * Constructors, `copy` and component functions of this type are not covered by Semantic Versioning; read its properties.
 */
data class BaresipAudioEvent(
    /** Whether the microphone is running. */
    val inputRunning: Boolean,
    /** Whether the speaker is running. */
    val outputRunning: Boolean,
    /** The error when audio could not start. */
    val error: BaresipError?,
)

/**
 * A diagnostic condition outside a call.
 *
 * Constructors, `copy` and component functions of this type are not covered by Semantic Versioning; read its properties.
 */
data class BaresipDiagnosticEvent(
    /** The severity. */
    val level: BaresipLogLevel,
    /** The description. */
    val message: String,
)

/**
 * An incoming SIP MESSAGE (RFC 3428).
 *
 * The constructor of this type is not covered by Semantic Versioning; read its properties.
 */
class BaresipMessage(
    /** The account that received the message, if known. */
    val accountId: BaresipAccountID?,
    /** The sender's URI. */
    val from: String,
    /** The `Content-Type` of the body, for example `text/plain`. */
    val contentType: String,
    /** The raw body. */
    val body: ByteArray,
) {
    /** The body decoded as UTF-8, or `null` when it is not valid UTF-8. */
    val text: String?
        get() =
            runCatching {
                Charsets.UTF_8
                    .newDecoder()
                    .decode(java.nio.ByteBuffer.wrap(body))
                    .toString()
            }.getOrNull()

    override fun equals(other: Any?): Boolean =
        other is BaresipMessage &&
            accountId == other.accountId &&
            from == other.from &&
            contentType == other.contentType &&
            body.contentEquals(other.body)

    override fun hashCode(): Int = listOf(accountId, from, contentType, body.contentHashCode()).hashCode()

    override fun toString(): String = "BaresipMessage(from=$from, contentType=$contentType, ${body.size} bytes)"
}

/**
 * The outcome of a message sent with [BaresipEngine.sendMessage].
 *
 * Constructors, `copy` and component functions of this type are not covered by Semantic Versioning; read its properties.
 */
data class BaresipMessageStatus(
    /** The message. */
    val id: BaresipMessageID,
    /** `true` when the peer answered with a 2xx response. */
    val delivered: Boolean,
    /** The final SIP response code, if a response arrived. */
    val sipStatus: Int?,
    /** The error when the message was not delivered. */
    val error: BaresipError?,
)
