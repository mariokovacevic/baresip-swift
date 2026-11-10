/// Identifies an outgoing SIP MESSAGE; BaresipMessageStatus reports its outcome.
///
/// Identifiers are assigned by the engine, are never reused while the engine runs, and are
/// only meaningful for the engine that created them.
public struct BaresipMessageID: Hashable, Sendable, Codable, CustomStringConvertible {
    /// The numeric value assigned by the core.
    public let rawValue: UInt64

    /// Creates an identifier from a value previously read from rawValue.
    ///
    /// - Parameter rawValue: The numeric value.
    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    /// A short form such as `message#3`, used in logs.
    public var description: String {
        "message#\(rawValue)"
    }
}
