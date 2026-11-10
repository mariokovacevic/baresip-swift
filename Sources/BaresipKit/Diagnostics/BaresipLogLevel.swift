/// The severity of a log entry.
public enum BaresipLogLevel: Int, Sendable, Comparable, Codable {
    /// Detailed information for debugging.
    case debug = 0
    /// Normal operational messages.
    case info = 1
    /// Something unexpected that the engine recovered from.
    case warning = 2
    /// A failure.
    case error = 3

    /// Whether `lhs` is less severe than `rhs`.
    ///
    /// - Parameters:
    ///   - lhs: A log level.
    ///   - rhs: Another log level.
    /// - Returns: `true` when `lhs` comes before `rhs` in the order debug, info, warning, error.
    public static func < (lhs: BaresipLogLevel, rhs: BaresipLogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
