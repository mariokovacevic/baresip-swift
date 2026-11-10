extension BaresipEngine {
    /// Current media statistics for a call.
    ///
    /// - Parameter callID: The call.
    /// - Returns: The statistics.
    /// - Throws: ``BaresipError`` with ``BaresipError/Code/notFound`` for an unknown call.
    public func callStatistics(callID: BaresipCallID) async throws -> BaresipCallStatistics {
        try await run { try $0.callStatistics(callID) }
    }
}
