/// A snapshot of a call, returned by ``BaresipEngine/callInfo(callID:)`` and carried by
/// ``BaresipEvent/incomingCall(_:earlyVideo:)``.
public struct BaresipCallInfo: Sendable, Equatable {
    /// The call.
    public let id: BaresipCallID
    /// The account the call belongs to.
    public let account: BaresipAccountID
    /// The call state when the snapshot was taken.
    public let state: BaresipCallState
    /// Whether the call was placed by this device.
    public let isOutgoing: Bool
    /// Whether the call has a video stream.
    public let hasVideo: Bool
    /// The negotiated audio direction.
    public let audioDirection: BaresipMediaDirection
    /// The negotiated video direction, from this device's side: `.receiveOnly` or
    /// `.sendReceive` means the peer's video reaches you. `.inactive` until the peer's SDP
    /// has arrived.
    public let videoDirection: BaresipMediaDirection
    /// The SIP `Call-ID` header value.
    public let sipCallID: String
    /// The remote party's URI.
    public let remoteURI: String
    /// The remote party's display name, or an empty string.
    public let remoteDisplayName: String
    /// The negotiated audio codec, or an empty string before negotiation.
    public let audioCodec: String
    /// The negotiated video codec, or an empty string.
    public let videoCodec: String
    /// The time from the INVITE to the answer.
    public let setupTime: Duration
    /// The time since the call was answered.
    public let duration: Duration
    /// Whether the microphone of this call is muted.
    public let isMicrophoneMuted: Bool
    /// The call this one takes over, or `nil`: an incoming call whose INVITE replaced an
    /// established call (`Replaces`, RFC 3891), or the outgoing call that follows when the other
    /// side transfers a call (REFER, RFC 3515). The call it takes over ends with
    /// ``BaresipCallEndReason/replaced``, and the conversation goes on in this call.
    public let replacesCallID: BaresipCallID?
}
