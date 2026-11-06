/// The outcome of a message sent with ``BaresipEngine/sendMessage(to:text:accountID:)``.
public struct BaresipMessageStatus: Sendable, Equatable {
    /// The message.
    public let id: BaresipMessageID
    /// `true` when the peer answered with a 2xx response.
    public let delivered: Bool
    /// The final SIP response code, if a response arrived.
    public let sipStatus: Int?
    /// The error when the message was not delivered.
    public let error: BaresipError?
}
