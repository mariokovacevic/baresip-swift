extension BaresipEngine {
    /// The largest SIP status code accepted by ``reject(callID:statusCode:reason:)``.
    static let maximumSIPStatusCode = 699

    /// Places a call.
    ///
    /// A destination without a scheme and domain, such as `1002`, is completed with the
    /// account's domain.
    ///
    /// Video is always offered, so the callee's early media and video are shown even in an
    /// audio call, for example a door station's camera while it rings. `video` only decides
    /// whether your camera is sent; change it later with `setVideoEnabled(_:callID:)`.
    ///
    /// - Parameters:
    ///   - accountID: The account to call from, or `nil` for the default account.
    ///   - destination: A SIP URI, user name or number.
    ///   - video: Whether to send your camera.
    ///   - audio: Whether audio flows. With `false` the audio stream is inactive in both
    ///     directions, for example to watch a door station's camera or to send a door-opening
    ///     DTMF code over SIP INFO without opening the microphone. Turn it on later with
    ///     ``setAudioDirection(_:callID:)``.
    /// - Returns: The new call's identifier. State changes arrive as ``BaresipEvent/call(_:_:_:)``.
    /// - Throws: ``BaresipError`` when there is no account, the destination is invalid or the
    ///   maximum number of calls is reached.
    public func makeCall(accountID: BaresipAccountID? = nil, destination: String,
                         video: Bool = false, audio: Bool = true) async throws -> BaresipCallID {
        try await run {
            try $0.makeCall(account: accountID, destination: destination, audio: audio, video: video)
        }
    }

    /// Answers an incoming call.
    ///
    /// The caller's video, if offered, is always received. `video` only decides whether your
    /// camera is sent; change it later with `setVideoEnabled(_:callID:)`.
    ///
    /// - Parameters:
    ///   - callID: The call.
    ///   - video: Whether to send your camera.
    ///   - audio: Whether audio flows. With `false` the call is answered silently, with the
    ///     audio stream inactive, for example to send a door-opening DTMF code.
    /// - Throws: ``BaresipError`` when the call is not ringing.
    public func answer(callID: BaresipCallID, video: Bool = false, audio: Bool = true) async throws {
        try await run { try $0.answer(callID, audio: audio, video: video) }
    }

    /// Starts a receive-only early media preview of an incoming call.
    ///
    /// The engine answers the INVITE with 183 Session Progress. You hear the caller, and with
    /// `earlyVideo` see them; the caller neither hears nor sees you until
    /// ``answer(callID:video:audio:)``. A video-only preview (`earlyAudio: false`) keeps the audio
    /// stream inactive, for example to show a door station's picture before ringing.
    ///
    /// - Parameters:
    ///   - callID: The ringing call.
    ///   - earlyVideo: Whether to receive the caller's video during the preview.
    ///   - earlyAudio: Whether to receive the caller's audio during the preview.
    /// - Throws: ``BaresipError`` when the call is not ringing.
    public func sendProgress(callID: BaresipCallID, earlyVideo: Bool = false,
                             earlyAudio: Bool = true) async throws {
        try await run { try $0.sendProgress(callID, earlyAudio: earlyAudio, earlyVideo: earlyVideo) }
    }

    /// Rejects an incoming call that is still ringing. End an answered call with
    /// ``hangup(callID:)``.
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
    /// - Throws: ``BaresipError`` with ``BaresipError/Code/notFound`` for an unknown call.
    public func hangup(callID: BaresipCallID) async throws {
        try await run { try $0.hangup(callID) }
    }

    /// Puts a call on hold.
    ///
    /// - Parameter callID: The call.
    /// - Throws: ``BaresipError`` when the call is not established. A hold requested while an
    ///   earlier change is still being negotiated is sent as soon as that change is done. When
    ///   the other side rejects the hold, the call returns to its previous state with an error
    ///   in the event.
    public func hold(callID: BaresipCallID) async throws {
        try await run { try $0.setHold(callID, true) }
    }

    /// Resumes a call from hold.
    ///
    /// - Parameter callID: The call.
    /// - Throws: ``BaresipError`` when the call is not established.
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
    public func blindTransfer(callID: BaresipCallID, to targetURI: String) async throws {
        try await run { try $0.transfer(callID, to: targetURI) }
    }

    /// Connects the remote party of a call to the party of a consultation call and leaves both
    /// calls (attended transfer).
    ///
    /// Typically `callID` is on hold and `consultationCallID` is the call to the transfer target.
    /// The engine sends a REFER with Replaces, so the consultation call is replaced and the
    /// target's phone does not ring again.
    ///
    /// - Parameters:
    ///   - callID: The call whose remote party is transferred.
    ///   - consultationCallID: The call to the transfer target, which is replaced.
    /// - Throws: ``BaresipError`` when either call is unknown or not established.
    public func attendedTransfer(callID: BaresipCallID,
                                 replacing consultationCallID: BaresipCallID) async throws {
        try await run { try $0.transferAttended(callID, to: consultationCallID) }
    }

    /// A snapshot of a call.
    ///
    /// - Parameter callID: The call.
    /// - Returns: The call's current information.
    /// - Throws: ``BaresipError`` with ``BaresipError/Code/notFound`` for an unknown call.
    public func callInfo(callID: BaresipCallID) async throws -> BaresipCallInfo {
        try await run { try $0.callInfo(callID) }
    }

    /// A header of the INVITE that started an incoming call, such as `X-Device-ID`.
    ///
    /// Only headers named in ``BaresipAccountConfiguration/incomingHeaders`` are kept.
    ///
    /// - Parameters:
    ///   - name: The header name, compared without case.
    ///   - callID: The incoming call.
    /// - Returns: The header value, or `nil` when the INVITE had no such header.
    /// - Throws: ``BaresipError`` for an unknown call.
    public func incomingHeader(_ name: String, callID: BaresipCallID) async throws -> String? {
        try await run { try $0.incomingHeader(name, call: callID) }
    }

    /// The identifiers of all calls that are not released.
    ///
    /// - Returns: The calls, oldest first.
    public func activeCalls() async -> [BaresipCallID] {
        await (try? run { $0.activeCalls() }) ?? []
    }
}
