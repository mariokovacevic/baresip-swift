package io.github.mariokovacevic.baresipkit.zvono.model

import io.github.mariokovacevic.baresipkit.BaresipCallEndReason
import io.github.mariokovacevic.baresipkit.BaresipCallID
import io.github.mariokovacevic.baresipkit.BaresipCallState
import io.github.mariokovacevic.baresipkit.compose.BaresipPhoneCall
import kotlin.time.Duration
import kotlin.time.TimeMark
import kotlin.time.TimeSource

data class CallRow(
    val id: BaresipCallID?,
    val remoteUri: String,
    val remoteName: String,
    val state: BaresipCallState,
    val outgoing: Boolean,
    val hasVideo: Boolean = false,
    val receivingVideo: Boolean = false,
    val sendingVideo: Boolean = false,
    val startedWithVideo: Boolean = false,
    val muted: Boolean = false,
    val previewing: Boolean = false,
    val codec: String = "",
    val startedAt: TimeMark = TimeSource.Monotonic.markNow(),
    val connectedAt: TimeMark? = null,
    val endedElsewhere: String? = null,
) {
    val title: String
        get() = remoteName.ifEmpty { SipNames.user(remoteUri) }.ifEmpty { "Call" }

    val initials: String
        get() = SipNames.initials(title)

    val isOnHold: Boolean
        get() = state == BaresipCallState.PAUSING || state == BaresipCallState.PAUSED || state == BaresipCallState.RESUMING

    val isConnected: Boolean
        get() = state == BaresipCallState.CONNECTED || state == BaresipCallState.STREAMS_RUNNING || state == BaresipCallState.UPDATING

    val isRinging: Boolean
        get() = !outgoing && (state == BaresipCallState.INCOMING || state == BaresipCallState.EARLY_MEDIA)

    val startedAtMillis: Long
        get() = System.currentTimeMillis() - startedAt.elapsedNow().inWholeMilliseconds

    val connectedAtMillis: Long?
        get() = connectedAt?.let { System.currentTimeMillis() - it.elapsedNow().inWholeMilliseconds }

    companion object {
        fun of(call: BaresipPhoneCall): CallRow =
            CallRow(
                id = call.id,
                remoteUri = call.remoteUri,
                remoteName = call.remoteDisplayName,
                state = call.state,
                outgoing = call.isOutgoing,
                hasVideo = call.hasVideo,
                receivingVideo = call.isReceivingVideo,
                sendingVideo = call.isSendingVideo,
                muted = call.isMuted,
                previewing = call.isPreviewing,
                codec = call.audioCodec,
                startedAt = call.startedAt,
                connectedAt = call.connectedAt,
                endedElsewhere =
                    when (call.error?.endReason) {
                        BaresipCallEndReason.ANSWERED_ELSEWHERE -> "answered"
                        BaresipCallEndReason.DECLINED_ELSEWHERE -> "declined"
                        BaresipCallEndReason.REPLACED, null -> null
                    },
            )
    }
}

object CallText {
    fun duration(elapsed: Duration): String {
        val seconds = elapsed.inWholeSeconds.coerceAtLeast(0)
        val hours = seconds / 3600
        val minutes = (seconds % 3600) / 60
        val rest = seconds % 60
        return if (hours > 0) "%d:%02d:%02d".format(hours, minutes, rest) else "%02d:%02d".format(minutes, rest)
    }

    fun status(row: CallRow): String {
        val talked = duration(row.connectedAt?.elapsedNow() ?: Duration.ZERO)
        return when (row.state) {
            BaresipCallState.INCOMING -> "Incoming"
            BaresipCallState.OUTGOING_INIT -> "Calling…"
            BaresipCallState.OUTGOING_RINGING -> "Ringing…"
            BaresipCallState.EARLY_MEDIA -> "Connecting…"
            BaresipCallState.CONNECTED, BaresipCallState.STREAMS_RUNNING, BaresipCallState.UPDATING, BaresipCallState.RESUMING -> talked
            BaresipCallState.PAUSING, BaresipCallState.PAUSED -> "On hold · $talked"
            BaresipCallState.PAUSED_BY_REMOTE -> "Held by the other side"
            BaresipCallState.ENDED, BaresipCallState.FAILED, BaresipCallState.RELEASED -> "Ended"
        }
    }
}
