/// Media statistics for a call, from ``BaresipEngine/callStatistics(callID:)`` or the periodic
/// ``BaresipEvent/statistics(_:_:)`` event.
public struct BaresipCallStatistics: Sendable, Equatable {
    /// The call.
    public let id: BaresipCallID
    /// Audio stream statistics.
    public let audio: BaresipStreamStatistics
    /// Video stream statistics.
    public let video: BaresipStreamStatistics
    /// The ICE state.
    public let iceState: BaresipICEState
    /// The type of the selected local candidate.
    public let localCandidate: BaresipCandidateType
    /// The type of the selected remote candidate.
    public let remoteCandidate: BaresipCandidateType
    /// The local media address.
    public let localAddress: String
    /// The remote media address.
    public let remoteAddress: String
    /// An estimated mean opinion score from 1 (bad) to 4.5 (excellent).
    public let mosEstimate: Float
    /// The current video encoder target in bits per second.
    public let videoTargetBitrate: Int
}
