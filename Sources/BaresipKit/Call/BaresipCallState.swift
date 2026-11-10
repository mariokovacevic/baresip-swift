/// The state of a call.
///
/// A call ends with ``ended`` or ``failed`` and is then ``released``; after
/// ``released`` its identifier is no longer valid.
public enum BaresipCallState: Int, Sendable, Codable {
    /// An incoming call is ringing.
    case incoming = 0
    /// An outgoing INVITE has been sent.
    case outgoingInit = 1
    /// The remote side is ringing.
    case outgoingRinging = 2
    /// Early media is flowing before the call is answered.
    case earlyMedia = 3
    /// The call was answered.
    case connected = 4
    /// Audio, and video when negotiated, is flowing.
    case streamsRunning = 5
    /// A local hold is being negotiated.
    case pausing = 6
    /// The call is on local hold.
    case paused = 7
    /// A resume from local hold is being negotiated.
    case resuming = 8
    /// The remote side put the call on hold.
    case pausedByRemote = 9
    /// A re-INVITE or UPDATE is in progress.
    case updating = 10
    /// The call ended normally.
    case ended = 11
    /// The call failed; the event carries the error.
    case failed = 12
    /// The call's resources were released.
    case released = 13

    /// `true` for ``ended``, ``failed`` and ``released``.
    public var isTerminal: Bool {
        self == .ended || self == .failed || self == .released
    }
}
