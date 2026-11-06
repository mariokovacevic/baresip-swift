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
    /// The negotiated video direction.
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
}
