/// One line of engine log output.
///
/// Credentials, authorization headers and push tokens are redacted by the core before an
/// entry reaches Swift.
public struct BaresipLogEntry: Sendable {
    /// The severity.
    public let level: BaresipLogLevel
    /// The part of the engine that wrote the entry.
    public let domain: BaresipLogDomain
    /// The text of the entry.
    public let message: String
}

/// A closure that receives log entries; see ``BaresipEngine/setLogHandler(_:)``.
///
/// The handler is called on the engine thread and must return quickly.
public typealias BaresipLogHandler = @Sendable (BaresipLogEntry) -> Void
