/// A notable condition reported by the engine outside a specific call, such as a TLS warning.
public struct BaresipDiagnosticEvent: Sendable, Equatable {
    /// The severity.
    public let level: BaresipLogLevel
    /// A human-readable description.
    public let message: String
}
