extension BaresipEngine {
    /// Sends a text message as a SIP MESSAGE (RFC 3428).
    ///
    /// The result arrives later as ``BaresipEvent/messageStatus(_:)`` with the returned
    /// identifier.
    ///
    /// - Parameters:
    ///   - peerURI: The recipient: a SIP URI, user name or number.
    ///   - text: The message text, sent as `text/plain`.
    ///   - accountID: The account to send from, or `nil` for the default account.
    /// - Returns: The message identifier.
    /// - Throws: ``BaresipError`` when there is no account or the recipient is invalid.
    @discardableResult
    public func sendMessage(to peerURI: String, text: String,
                            accountID: BaresipAccountID? = nil) async throws -> BaresipMessageID {
        let account = resolvedAccount(accountID)
        return try await run { try $0.sendMessage(account: account, to: peerURI, text: text) }
    }
}
