extension BaresipEngine {
    /// Restarts ICE for a call with new credentials, for example after a network change.
    ///
    /// - Parameter callID: The call.
    /// - Throws: ``BaresipError`` when the call does not use ICE.
    public func restartICE(callID: BaresipCallID) async throws {
        try await run { try $0.restartICE(callID) }
    }
}
