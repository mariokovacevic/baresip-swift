package io.github.mariokovacevic.baresipkit.internal

import io.github.mariokovacevic.baresipkit.BaresipAccountID
import io.github.mariokovacevic.baresipkit.BaresipAudioEvent
import io.github.mariokovacevic.baresipkit.BaresipCallEndReason
import io.github.mariokovacevic.baresipkit.BaresipCallID
import io.github.mariokovacevic.baresipkit.BaresipCallInfo
import io.github.mariokovacevic.baresipkit.BaresipCallState
import io.github.mariokovacevic.baresipkit.BaresipCallStatistics
import io.github.mariokovacevic.baresipkit.BaresipCandidateType
import io.github.mariokovacevic.baresipkit.BaresipDiagnosticEvent
import io.github.mariokovacevic.baresipkit.BaresipDtmfEvent
import io.github.mariokovacevic.baresipkit.BaresipEngineState
import io.github.mariokovacevic.baresipkit.BaresipError
import io.github.mariokovacevic.baresipkit.BaresipEvent
import io.github.mariokovacevic.baresipkit.BaresipIceEvent
import io.github.mariokovacevic.baresipkit.BaresipIceState
import io.github.mariokovacevic.baresipkit.BaresipLogLevel
import io.github.mariokovacevic.baresipkit.BaresipMediaDirection
import io.github.mariokovacevic.baresipkit.BaresipMediaEvent
import io.github.mariokovacevic.baresipkit.BaresipMediaEventInfo
import io.github.mariokovacevic.baresipkit.BaresipMessage
import io.github.mariokovacevic.baresipkit.BaresipMessageID
import io.github.mariokovacevic.baresipkit.BaresipMessageStatus
import io.github.mariokovacevic.baresipkit.BaresipNetworkEvent
import io.github.mariokovacevic.baresipkit.BaresipRegistrationState
import io.github.mariokovacevic.baresipkit.BaresipStreamStatistics
import io.github.mariokovacevic.baresipkit.BaresipTransferEvent
import kotlin.time.Duration.Companion.milliseconds
import kotlin.time.Duration.Companion.seconds

internal object EventDecoder {
    const val CALL_INFO_LONGS = 10
    const val STATISTICS_LONGS = 30
    private const val FIRST_LONG = 4
    private const val FIRST_STRING = 2

    private const val ENGINE_STATE = 0
    private const val REGISTRATION = 1
    private const val CALL_STATE = 2
    private const val CALL_INCOMING = 3
    private const val CALL_MEDIA = 4
    private const val CALL_DTMF = 5
    private const val CALL_TRANSFER = 6
    private const val CALL_STATISTICS = 7
    private const val ICE = 8
    private const val NETWORK = 9
    private const val AUDIO = 10
    private const val DIAGNOSTIC = 11
    private const val MESSAGE = 12
    private const val MESSAGE_STATUS = 13

    fun decode(
        type: Int,
        account: Long,
        call: Long,
        n: LongArray,
        s: Array<String?>,
        body: ByteArray?,
    ): BaresipEvent? {
        val x = n.copyOfRange(FIRST_LONG, n.size)
        val y = s.copyOfRange(FIRST_STRING, s.size)
        val error = error(n, s)
        val callID = BaresipCallID(call)
        return when (type) {
            ENGINE_STATE -> BaresipEvent.Engine(BaresipEngineState.of(x[0].toInt()), error)
            REGISTRATION ->
                BaresipEvent.Registration(
                    BaresipAccountID(account),
                    BaresipRegistrationState.of(x[0].toInt()),
                    x[1].takeIf { it != 0L }?.seconds,
                    error,
                )
            CALL_STATE -> BaresipEvent.Call(callID, BaresipCallState.of(x[0].toInt()), error)
            CALL_INCOMING -> BaresipEvent.IncomingCall(callInfo(x, y), x[CALL_INFO_LONGS] != 0L)
            CALL_MEDIA ->
                BaresipEvent.Media(
                    callID,
                    BaresipMediaEventInfo(
                        BaresipMediaEvent.of(x[0].toInt()),
                        BaresipMediaDirection.of(x[1].toInt()),
                        BaresipMediaDirection.of(x[2].toInt()),
                        y[0].orEmpty(),
                    ),
                )
            CALL_DTMF -> BaresipEvent.Dtmf(callID, BaresipDtmfEvent(x[0].toInt().toChar(), x[1] != 0L, x[2] != 0L))
            CALL_TRANSFER ->
                BaresipEvent.Transfer(
                    callID,
                    BaresipTransferEvent(x[0] != 0L, x[1].toInt().takeIf { it != 0 }, y[0].orEmpty()),
                )
            CALL_STATISTICS -> BaresipEvent.Statistics(callID, statistics(x, y))
            ICE ->
                BaresipEvent.Ice(
                    callID,
                    BaresipIceEvent(
                        BaresipIceState.of(x[0].toInt()),
                        BaresipCandidateType.of(x[1].toInt()),
                        BaresipCandidateType.of(x[2].toInt()),
                        y[0].orEmpty(),
                        y[1].orEmpty(),
                    ),
                )
            NETWORK -> BaresipEvent.Network(BaresipNetworkEvent(x[0] != 0L, y[0].orEmpty()))
            AUDIO ->
                BaresipEvent.Audio(
                    callID.takeIf { call != 0L },
                    BaresipAudioEvent(x[0] != 0L, x[1] != 0L, error),
                )
            DIAGNOSTIC ->
                BaresipEvent.Diagnostic(BaresipDiagnosticEvent(BaresipLogLevel.of(x[0].toInt()), y[0].orEmpty()))
            MESSAGE ->
                BaresipEvent.Message(
                    BaresipMessage(
                        BaresipAccountID(account).takeIf { account != 0L },
                        y[0].orEmpty(),
                        y[1].orEmpty(),
                        body ?: ByteArray(0),
                    ),
                )
            MESSAGE_STATUS ->
                BaresipEvent.MessageStatus(
                    BaresipMessageStatus(
                        BaresipMessageID(x[0]),
                        x[1] != 0L,
                        x[2].toInt().takeIf { it != 0 },
                        error,
                    ),
                )
            else -> null
        }
    }

    private fun error(
        n: LongArray,
        s: Array<String?>,
    ): BaresipError? {
        val status = n[0].toInt()
        val sipStatus = n[2].toInt()
        val endReason = BaresipCallEndReason.of(n[3].toInt())
        if (status == 0 && sipStatus == 0 && endReason == null) return null
        return BaresipError(
            code = BaresipError.Code.of(status),
            systemErrno = n[1].toInt(),
            sipStatus = sipStatus.takeIf { it != 0 },
            sipReason = s[0].orEmpty(),
            detail = s[1].orEmpty(),
            endReason = endReason,
        )
    }

    fun callInfo(
        n: LongArray,
        s: Array<String?>,
    ): BaresipCallInfo =
        BaresipCallInfo(
            id = BaresipCallID(n[0]),
            account = BaresipAccountID(n[1]),
            state = BaresipCallState.of(n[2].toInt()),
            isOutgoing = n[3] != 0L,
            hasVideo = n[4] != 0L,
            audioDirection = BaresipMediaDirection.of(n[5].toInt()),
            videoDirection = BaresipMediaDirection.of(n[6].toInt()),
            sipCallId = s[0].orEmpty(),
            remoteUri = s[1].orEmpty(),
            remoteDisplayName = s[2].orEmpty(),
            audioCodec = s[3].orEmpty(),
            videoCodec = s[4].orEmpty(),
            setupTime = n[7].milliseconds,
            duration = n[8].seconds,
            isMicrophoneMuted = n[9] != 0L,
        )

    fun statistics(
        n: LongArray,
        s: Array<String?>,
    ): BaresipCallStatistics =
        BaresipCallStatistics(
            id = BaresipCallID(n[0]),
            iceState = BaresipIceState.of(n[1].toInt()),
            localCandidate = BaresipCandidateType.of(n[2].toInt()),
            remoteCandidate = BaresipCandidateType.of(n[3].toInt()),
            mosEstimate = Double.fromBits(n[4]),
            videoTargetBitrate = n[5].toInt(),
            audio = stream(n, 6),
            video = stream(n, 18),
            localAddress = s[0].orEmpty(),
            remoteAddress = s[1].orEmpty(),
        )

    private fun stream(
        n: LongArray,
        i: Int,
    ): BaresipStreamStatistics =
        BaresipStreamStatistics(
            transmittedPackets = n[i],
            receivedPackets = n[i + 1],
            transmittedBytes = n[i + 2],
            receivedBytes = n[i + 3],
            receivedLost = n[i + 4].toInt(),
            receivedFractionLostPermille = n[i + 5].toInt(),
            receivedJitter = n[i + 6].milliseconds,
            roundTripTime = n[i + 7].milliseconds,
            transmitBitrate = n[i + 8],
            receiveBitrate = n[i + 9],
            jitterBufferDelay = n[i + 10].milliseconds,
            isSecure = n[i + 11] != 0L,
        )
}
