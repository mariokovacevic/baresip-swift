import Foundation

/// An incoming SIP MESSAGE (RFC 3428).
public struct BaresipMessage: Sendable, Equatable {
    /// The account that received the message, if known.
    public let accountID: BaresipAccountID?
    /// The sender's URI.
    public let from: String
    /// The `Content-Type` of the body, for example `text/plain`.
    public let contentType: String
    /// The raw body.
    public let body: Data

    /// The body decoded as UTF-8, or `nil` when it is not valid UTF-8.
    public var text: String? {
        String(data: body, encoding: .utf8)
    }
}
