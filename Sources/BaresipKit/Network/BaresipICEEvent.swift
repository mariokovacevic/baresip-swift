/// A change in a call's ICE state or selected candidate pair.
public struct BaresipICEEvent: Sendable, Equatable {
    /// The ICE state.
    public let state: BaresipICEState
    /// The type of the selected local candidate.
    public let localCandidate: BaresipCandidateType
    /// The type of the selected remote candidate.
    public let remoteCandidate: BaresipCandidateType
    /// The selected local address.
    public let localAddress: String
    /// The selected remote address.
    public let remoteAddress: String
}
