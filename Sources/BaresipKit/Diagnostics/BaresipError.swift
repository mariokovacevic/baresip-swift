/// An error thrown by BaresipKit.
///
/// ``status`` tells what kind of failure happened. SIP failures also carry the response code
/// and reason phrase, and ``message`` holds a human-readable explanation from the core.
///
/// ```swift
/// do {
///     try await engine.hold(callID: call)
/// } catch let error as BaresipError where error.status == .notFound {
///     print("The call has already ended")
/// }
/// ```
public struct BaresipError: Error, Sendable, Equatable, CustomStringConvertible {
    /// The category of the failure.
    public let status: BaresipStatus
    /// The underlying POSIX `errno`, or `0` when there is none.
    public let systemErrno: Int32
    /// The SIP response code when the failure came from a SIP transaction.
    public let sipStatus: Int?
    /// The SIP reason phrase, or an empty string.
    public let sipReason: String
    /// A human-readable explanation, or an empty string.
    public let message: String

    /// Creates an error.
    ///
    /// - Parameters:
    ///   - status: The category of the failure.
    ///   - systemErrno: The underlying POSIX `errno`, if any.
    ///   - sipStatus: The SIP response code, if any.
    ///   - sipReason: The SIP reason phrase.
    ///   - message: A human-readable explanation.
    public init(status: BaresipStatus, systemErrno: Int32 = 0, sipStatus: Int? = nil,
                sipReason: String = "", message: String = "") {
        self.status = status
        self.systemErrno = systemErrno
        self.sipStatus = sipStatus
        self.sipReason = sipReason
        self.message = message
    }

    /// `true` unless ``status`` is ``BaresipStatus/ok``.
    public var isFailure: Bool {
        status != .ok
    }

    /// The status, SIP response and message joined into one line.
    public var description: String {
        var parts = ["\(status)"]
        if let sipStatus {
            parts.append("SIP \(sipStatus) \(sipReason)")
        }
        if !message.isEmpty {
            parts.append(message)
        }
        return parts.joined(separator: ": ")
    }
}
