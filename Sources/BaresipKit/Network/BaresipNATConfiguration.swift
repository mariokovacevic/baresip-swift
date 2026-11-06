/// NAT traversal settings for an account.
public struct BaresipNATConfiguration: Sendable, Equatable {
    /// The traversal method.
    public var mode: BaresipNATTraversal
    /// The STUN server, for example `stun:stun.example.com:3478`.
    public var stunURI: String?
    /// TURN relays used by ICE.
    public var turnServers: [BaresipTURNServer]
    /// Whether RTP is sent back to the address it actually arrives from.
    public var symmetricRTPLatching: Bool
    /// How long a call may receive no RTP before ``BaresipMediaEvent/rtpTimeout`` is reported.
    public var rtpTimeout: Duration

    /// Creates NAT settings.
    ///
    /// - Parameters:
    ///   - mode: The traversal method.
    ///   - stunURI: The STUN server.
    ///   - turnServers: TURN relays for ICE.
    ///   - symmetricRTPLatching: Whether to latch onto the source address of incoming RTP.
    ///   - rtpTimeout: The RTP inactivity timeout.
    public init(mode: BaresipNATTraversal = .none, stunURI: String? = nil,
                turnServers: [BaresipTURNServer] = [], symmetricRTPLatching: Bool = true,
                rtpTimeout: Duration = .seconds(30)) {
        self.mode = mode
        self.stunURI = stunURI
        self.turnServers = turnServers
        self.symmetricRTPLatching = symmetricRTPLatching
        self.rtpTimeout = rtpTimeout
    }
}
