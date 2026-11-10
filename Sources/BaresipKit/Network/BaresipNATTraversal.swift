/// The NAT traversal method for an account's calls.
public enum BaresipNATTraversal: Int, Sendable, Codable {
    /// No NAT traversal beyond symmetric RTP latching.
    case none = 0
    /// STUN to learn the public address.
    case stun = 1
    /// ICE with STUN and, when configured, TURN relays.
    case ice = 2
}
