extension BaresipEngine {
    /// The largest SIP status code accepted by ``reject(callID:statusCode:reason:)``.
    static let maximumSIPStatusCode = 699

    /// Places a call.
    ///
    /// A destination without a scheme and domain, such as `1002`, is completed with the
    /// account's domain.
    ///
    /// - Parameters:
    ///   - accountID: The account to call from, or `nil` for the default account.
    ///   - destination: A SIP URI, user name or number.
    ///   - video: Whether to offer video.
    /// - Returns: The new call's identifier. State changes arrive as ``BaresipEvent/call(_:_:_:)``.
    /// - Throws: ``BaresipError`` when there is no account, the destination is invalid or the
    ///   maximum number of calls is reached.
    public func makeCall(accountID: BaresipAccountID? = nil, destination: String,
                         video: Bool = false) async throws -> BaresipCallID {
        let account = resolvedAccount(accountID)
        return try await run { try $0.makeCall(account: account, destination: destination, video: video) }
    }

    /// Answers an incoming call.
    ///
    /// - Parameters:
    ///   - callID: The call.
    ///   - video: Whether to accept the offered video.
    /// - Throws: ``BaresipError`` when the call is not ringing.
    public func answer(callID: BaresipCallID, video: Bool = false) async throws {
        try await run { try $0.answer(callID, video: video) }
    }

    /// Starts a receive-only early media preview of an incoming call.
    ///
    /// The engine answers the INVITE with 183 Session Progress. You hear, and with
    /// `earlyVideo` see, the caller; the caller neither hears nor sees you until
    /// ``answer(callID:video:)``.
    ///
    /// - Parameters:
    ///   - callID: The ringing call.
    ///   - earlyVideo: Whether to receive the caller's video during the preview.
    /// - Throws: ``BaresipError`` when the call is not ringing.
    public func sendProgress(callID: BaresipCallID, earlyVideo: Bool = false) async throws {
        try await run { try $0.sendProgress(callID, earlyVideo: earlyVideo) }
    }

    /// Rejects an incoming call.
    ///
    /// - Parameters:
    ///   - callID: The ringing call.
    ///   - statusCode: The SIP response code, 486 Busy Here by default.
    ///   - reason: The reason phrase, or `nil` for the standard phrase.
    /// - Throws: ``BaresipError`` when the call is not ringing or the code is not 300–699.
    public func reject(callID: BaresipCallID, statusCode: Int = 486, reason: String? = nil) async throws {
        let code = UInt16(clamping: min(max(statusCode, 0), Self.maximumSIPStatusCode))
        try await run { try $0.reject(callID, statusCode: code, reason: reason) }
    }

    /// Hangs up a call in any state.
    ///
    /// - Parameter callID: The call.
    /// - Throws: ``BaresipError`` with ``BaresipStatus/notFound`` for an unknown call.
    public func hangup(callID: BaresipCallID) async throws {
        try await run { try $0.hangup(callID) }
    }

    /// Puts a call on hold.
    ///
    /// - Parameter callID: The call.
    /// - Throws: ``BaresipError`` when the call is not established.
    public func hold(callID: BaresipCallID) async throws {
        try await run { try $0.setHold(callID, true) }
    }

    /// Resumes a call from hold.
    ///
    /// - Parameter callID: The call.
    /// - Throws: ``BaresipError`` when the call is not on hold.
    public func resume(callID: BaresipCallID) async throws {
        try await run { try $0.setHold(callID, false) }
    }

    /// Makes a call the active one: other established calls are put on hold, and this call
    /// is resumed if it was held.
    ///
    /// - Parameter callID: The call.
    /// - Throws: ``BaresipError`` for an unknown call.
    public func setActiveCall(_ callID: BaresipCallID) async throws {
        try await run { try $0.setActive(callID) }
    }

    /// Sends DTMF digits.
    ///
    /// - Parameters:
    ///   - callID: The call.
    ///   - digits: Digits from `0`–`9`, `*`, `#` and `A`–`D`.
    ///   - duration: How long each digit is sent.
    ///   - gap: The pause between digits.
    /// - Throws: ``BaresipError`` for an unknown call or invalid digits.
    public func sendDTMF(callID: BaresipCallID, digits: String,
                         duration: Duration = .milliseconds(160),
                         gap: Duration = .milliseconds(80)) async throws {
        try await run { try $0.sendDTMF(callID, digits: digits, duration: duration, gap: gap) }
    }

    /// Transfers a call to another party without consulting them first (blind transfer).
    ///
    /// - Parameters:
    ///   - callID: The call to transfer.
    ///   - targetURI: Where the remote party is sent.
    /// - Throws: ``BaresipError`` when the call is not established.
    public func transfer(callID: BaresipCallID, to targetURI: String) async throws {
        try await run { try $0.transfer(callID, to: targetURI) }
    }

    /// Connects the remote parties of two calls and leaves both (attended transfer).
    ///
    /// Typically `callID` is on hold and `targetCallID` is the consultation call. The engine
    /// sends a REFER with Replaces, so the target's phone does not ring again.
    ///
    /// - Parameters:
    ///   - callID: The call whose remote party is transferred.
    ///   - targetCallID: The call the remote party is connected to.
    /// - Throws: ``BaresipError`` when either call is unknown or not established.
    public func transferAttended(callID: BaresipCallID, to targetCallID: BaresipCallID) async throws {
        try await run { try $0.transferAttended(callID, to: targetCallID) }
    }

    /// A snapshot of a call.
    ///
    /// - Parameter callID: The call.
    /// - Returns: The call's current information.
    /// - Throws: ``BaresipError`` with ``BaresipStatus/notFound`` for an unknown call.
    public func callInfo(callID: BaresipCallID) async throws -> BaresipCallInfo {
        try await run { try $0.callInfo(callID) }
    }

    /// The identifiers of all calls that are not released.
    ///
    /// - Returns: The calls, oldest first.
    public func activeCalls() async -> [BaresipCallID] {
        await (try? run { $0.activeCalls() }) ?? []
    }
}
