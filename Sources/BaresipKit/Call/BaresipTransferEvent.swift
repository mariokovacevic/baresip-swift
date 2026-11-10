/// Progress of a call transfer.
public struct BaresipTransferEvent: Sendable, Equatable {
    /// `true` when the transfer failed.
    public let failed: Bool
    /// The SIP response code reported for the transfer, if any.
    public let sipStatus: Int?
    /// The transfer target.
    public let targetURI: String
}
