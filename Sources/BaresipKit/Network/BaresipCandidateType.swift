/// The type of an ICE candidate.
public enum BaresipCandidateType: Int, Sendable, Codable {
    /// A local interface address.
    case host = 0
    /// The public address learned from STUN.
    case serverReflexive = 1
    /// An address learned during connectivity checks.
    case peerReflexive = 2
    /// An address on a TURN relay.
    case relay = 3
}
