package io.github.mariokovacevic.baresipkit

import kotlin.time.Duration

/** A snapshot of a call, returned by [BaresipEngine.callInfo] and carried by [BaresipEvent.IncomingCall]. */
data class BaresipCallInfo(
    /** The call. */
    val id: BaresipCallID,
    /** The account the call belongs to. */
    val account: BaresipAccountID,
    /** The call state when the snapshot was taken. */
    val state: BaresipCallState,
    /** Whether the call was placed by this device. */
    val isOutgoing: Boolean,
    /** Whether the call has a video stream. */
    val hasVideo: Boolean,
    /** The negotiated audio direction. */
    val audioDirection: BaresipMediaDirection,
    /**
     * The negotiated video direction, from this device's side: [BaresipMediaDirection.RECEIVE_ONLY]
     * or [BaresipMediaDirection.SEND_RECEIVE] means the peer's video reaches you.
     */
    val videoDirection: BaresipMediaDirection,
    /** The SIP `Call-ID` header value. */
    val sipCallId: String,
    /** The remote party's URI. */
    val remoteUri: String,
    /** The remote party's display name, or an empty string. */
    val remoteDisplayName: String,
    /** The negotiated audio codec, or an empty string before negotiation. */
    val audioCodec: String,
    /** The negotiated video codec, or an empty string. */
    val videoCodec: String,
    /** The time from the INVITE to the answer. */
    val setupTime: Duration,
    /** The time since the call was answered. */
    val duration: Duration,
    /** Whether the microphone of this call is muted. */
    val isMicrophoneMuted: Boolean,
    /**
     * The call this one takes over, or `null`: an incoming call whose INVITE replaced an established
     * call (`Replaces`, RFC 3891), or the outgoing call that follows when the other side transfers a
     * call (REFER, RFC 3515). The call it takes over ends with [BaresipCallEndReason.REPLACED], and
     * the conversation goes on in this call.
     */
    val replacesCallId: BaresipCallID? = null,
)

/** RTP statistics for one stream of a call. */
data class BaresipStreamStatistics(
    /** RTP packets sent. */
    val transmittedPackets: Long,
    /** RTP packets received. */
    val receivedPackets: Long,
    /** RTP payload bytes sent. */
    val transmittedBytes: Long,
    /** RTP payload bytes received. */
    val receivedBytes: Long,
    /** The cumulative number of packets lost in the received stream. */
    val receivedLost: Int,
    /** The fraction of received packets lost, in tenths of a percent. */
    val receivedFractionLostPermille: Int,
    /** The interarrival jitter of the received stream. */
    val receivedJitter: Duration,
    /** The round-trip time from RTCP. */
    val roundTripTime: Duration,
    /** The sending bitrate in bits per second. */
    val transmitBitrate: Long,
    /** The receiving bitrate in bits per second. */
    val receiveBitrate: Long,
    /** The current jitter buffer delay. */
    val jitterBufferDelay: Duration,
    /** Whether the stream is encrypted. */
    val isSecure: Boolean,
)

/** Media statistics of a call. */
data class BaresipCallStatistics(
    /** The call. */
    val id: BaresipCallID,
    /** The audio stream. */
    val audio: BaresipStreamStatistics,
    /** The video stream. */
    val video: BaresipStreamStatistics,
    /** The ICE state. */
    val iceState: BaresipIceState,
    /** The type of the local candidate in use. */
    val localCandidate: BaresipCandidateType,
    /** The type of the remote candidate in use. */
    val remoteCandidate: BaresipCandidateType,
    /** The local media address. */
    val localAddress: String,
    /** The remote media address. */
    val remoteAddress: String,
    /** An estimate of the mean opinion score, 1 to 4.5. */
    val mosEstimate: Double,
    /** The bitrate the video encoder currently aims for. */
    val videoTargetBitrate: Int,
)
