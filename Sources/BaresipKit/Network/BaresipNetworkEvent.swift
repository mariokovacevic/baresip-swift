/// The engine's reaction to a network change; see ``BaresipEngine/networkDidChange(reregister:updateCalls:)``.
public struct BaresipNetworkEvent: Sendable, Equatable {
    /// Whether SIP transports were recreated on a new local address.
    public let transportsReset: Bool
    /// The local address in use after the change.
    public let localAddress: String
}
