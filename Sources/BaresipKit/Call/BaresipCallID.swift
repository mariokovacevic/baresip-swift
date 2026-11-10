/// Identifies a call; the same identifier is used in every event about the call.
///
/// Identifiers are assigned by the engine, are never reused while the engine runs, and are
/// only meaningful for the engine that created them.
public struct BaresipCallID: Hashable, Sendable, Codable, CustomStringConvertible {
    /// The numeric value assigned by the core.
    public let rawValue: UInt64

    /// Creates an identifier from a value previously read from rawValue.
    ///
    /// - Parameter rawValue: The numeric value.
    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    /// A short form such as `call#3`, used in logs.
    public var description: String {
        "call#\(rawValue)"
    }
}
