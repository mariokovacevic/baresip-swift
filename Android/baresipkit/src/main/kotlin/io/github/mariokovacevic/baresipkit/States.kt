package io.github.mariokovacevic.baresipkit

/** The lifecycle state of an engine. */
public enum class BaresipEngineState {
    /** Created, not started. */
    IDLE,

    /** Starting up. */
    STARTING,

    /** Started; transports are open. */
    READY,

    /** Running with the engine thread. */
    RUNNING,

    /** Stopping. */
    STOPPING,

    /** Stopped. */
    STOPPED,

    /** Failed to start or crashed; the event carries the error. */
    FAILED,
    ;

    internal companion object {
        fun of(code: Int): BaresipEngineState = entries.getOrElse(code) { FAILED }
    }
}

/** The registration state of an account. */
public enum class BaresipRegistrationState {
    /** Not registered. */
    NONE,

    /** A REGISTER is in progress. */
    REGISTERING,

    /** Registered with the registrar. */
    REGISTERED,

    /** An un-REGISTER is in progress. */
    UNREGISTERING,

    /** The registration failed; the event carries the error. */
    FAILED,
    ;

    internal companion object {
        fun of(code: Int): BaresipRegistrationState = entries.getOrElse(code) { NONE }
    }
}

/**
 * The state of a call.
 *
 * A call ends with [ENDED] or [FAILED] and is then [RELEASED]; after [RELEASED] its identifier is
 * no longer valid.
 *
 * New entries can be added in a minor release; give a `when` over it an `else` branch. See
 * [Stability](https://github.com/mariokovacevic/baresipkit/blob/main/Docs/STABILITY.md).
 */
public enum class BaresipCallState {
    /** An incoming call is ringing. */
    INCOMING,

    /** An outgoing INVITE has been sent. */
    OUTGOING_INIT,

    /** The remote side is ringing. */
    OUTGOING_RINGING,

    /** Early media is flowing before the call is answered. */
    EARLY_MEDIA,

    /** The call was answered. */
    CONNECTED,

    /** Audio, and video when negotiated, is flowing. */
    STREAMS_RUNNING,

    /** A local hold is being negotiated. */
    PAUSING,

    /** The call is on local hold. */
    PAUSED,

    /** A resume from local hold is being negotiated. */
    RESUMING,

    /** The remote side put the call on hold. */
    PAUSED_BY_REMOTE,

    /** A re-INVITE or UPDATE is in progress. */
    UPDATING,

    /** The call ended normally. */
    ENDED,

    /** The call failed; the event carries the error. */
    FAILED,

    /** The call's resources were released. */
    RELEASED,
    ;

    /** `true` for [ENDED], [FAILED] and [RELEASED]. */
    public val isTerminal: Boolean
        get() = this == ENDED || this == FAILED || this == RELEASED

    internal companion object {
        fun of(code: Int): BaresipCallState = entries.getOrElse(code) { FAILED }
    }
}

/** The SIP transport of an account. */
public enum class BaresipTransport {
    /** SIP over UDP. */
    UDP,

    /** SIP over TCP. */
    TCP,

    /** SIP over TLS. */
    TLS,

    /** SIP over secure WebSocket. */
    WSS,
}

/** Media encryption for the calls of an account. */
public enum class BaresipMediaEncryption {
    /** Unencrypted RTP. */
    NONE,

    /** SRTP with SDES keys when the peer supports it, RTP otherwise. */
    SRTP_OPTIONAL,

    /** SRTP with SDES keys; calls without it fail. */
    SRTP_MANDATORY,

    /** SRTP keyed with DTLS. */
    DTLS_SRTP,
}

/** The NAT traversal method of an account. */
public enum class BaresipNatTraversal {
    /** No NAT traversal. */
    NONE,

    /** The public address from STUN. */
    STUN,

    /** ICE with STUN and TURN candidates. */
    ICE,
}

/** How DTMF digits are sent. */
public enum class BaresipDtmfMode {
    /** RTP events when the peer offers them, SIP INFO otherwise. */
    AUTO,

    /** RTP events (RFC 4733). */
    RTP_EVENT,

    /** SIP INFO requests. */
    SIP_INFO,
}

/** The direction of a media stream, from this device's side. */
public enum class BaresipMediaDirection {
    /** Nothing flows. */
    INACTIVE,

    /** This device sends only. */
    SEND_ONLY,

    /** This device receives only. */
    RECEIVE_ONLY,

    /** Media flows both ways. */
    SEND_RECEIVE,
    ;

    internal companion object {
        fun of(code: Int): BaresipMediaDirection = entries.getOrElse(code) { INACTIVE }
    }
}

/** The ICE state of a call. */
public enum class BaresipIceState {
    /** ICE is not used. */
    NONE,

    /** Candidates are being gathered. */
    GATHERING,

    /** Connectivity checks are running. */
    CHECKING,

    /** A candidate pair was selected. */
    CONNECTED,

    /** No candidate pair works. */
    FAILED,
    ;

    internal companion object {
        fun of(code: Int): BaresipIceState = entries.getOrElse(code) { NONE }
    }
}

/** The type of an ICE candidate. */
public enum class BaresipCandidateType {
    /** A local interface address. */
    HOST,

    /** The public address seen by a STUN server. */
    SERVER_REFLEXIVE,

    /** An address learned from a connectivity check. */
    PEER_REFLEXIVE,

    /** A TURN relay address. */
    RELAY,
    ;

    internal companion object {
        fun of(code: Int): BaresipCandidateType = entries.getOrElse(code) { HOST }
    }
}

/**
 * Why a call ended other than by a hang-up or a failure; see [BaresipError.endReason].
 *
 * New entries can be added in a minor release; give a `when` over it an `else` branch. See
 * [Stability](https://github.com/mariokovacevic/baresipkit/blob/main/Docs/STABILITY.md).
 */
public enum class BaresipCallEndReason {
    /** Another device answered the call (`Reason: SIP;cause=200`). */
    ANSWERED_ELSEWHERE,

    /** Another device declined the call (`Reason: SIP;cause=600` or `603`). */
    DECLINED_ELSEWHERE,

    /**
     * Another call took the conversation over: the server replaced this call with a new INVITE
     * (`Replaces`), or the other side transferred it and the engine followed the transfer. The new
     * call's [BaresipCallInfo.replacesCallId] is this call. Do not show the call as ended.
     */
    REPLACED,
    ;

    internal companion object {
        fun of(code: Int): BaresipCallEndReason? =
            when (code) {
                1 -> ANSWERED_ELSEWHERE
                2 -> DECLINED_ELSEWHERE
                3 -> REPLACED
                else -> null
            }
    }
}
