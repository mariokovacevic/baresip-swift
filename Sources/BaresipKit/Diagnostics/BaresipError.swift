/// An error thrown by BaresipKit.
///
/// ``code`` tells what kind of failure happened. SIP failures also carry the response code
/// and reason phrase, and ``message`` holds a human-readable explanation from the core.
///
/// ```swift
/// do {
///     try await engine.hold(callID: call)
/// } catch let error as BaresipError where error.code == .notFound {
///     print("The call has already ended")
/// }
/// ```
public struct BaresipError: Error, Sendable, Equatable, CustomStringConvertible {
    /// The category of the failure.
    public let code: Code
    /// The underlying POSIX `errno`, or `0` when there is none.
    public let systemErrno: Int32
    /// The SIP response code when the failure came from a SIP transaction.
    public let sipStatus: Int?
    /// The SIP reason phrase, or an empty string.
    public let sipReason: String
    /// A human-readable explanation, or an empty string.
    public let message: String
    /// For an incoming call that ended while it rang, whether another device answered or
    /// declined it, as the `Reason` header of the server's CANCEL said (RFC 3326); `nil`
    /// otherwise. ``sipStatus`` and ``sipReason`` then hold the header's cause and text.
    ///
    /// When several phones ring for one call and one answers, the server cancels the others.
    /// Report such a call as answered elsewhere instead of as missed.
    ///
    /// ``BaresipCallEndReason/replaced`` marks a call that another call took over, with
    /// ``code`` ``Code/ok``.
    public let endReason: BaresipCallEndReason?

    /// Creates an error.
    ///
    /// - Parameters:
    ///   - code: The category of the failure.
    ///   - systemErrno: The underlying POSIX `errno`, if any.
    ///   - sipStatus: The SIP response code, if any.
    ///   - sipReason: The SIP reason phrase.
    ///   - message: A human-readable explanation.
    ///   - endReason: How another device ended a ringing call, if it did.
    public init(code: Code, systemErrno: Int32 = 0, sipStatus: Int? = nil,
                sipReason: String = "", message: String = "", endReason: BaresipCallEndReason? = nil) {
        self.code = code
        self.systemErrno = systemErrno
        self.sipStatus = sipStatus
        self.sipReason = sipReason
        self.message = message
        self.endReason = endReason
    }

    /// `true` unless ``code`` is ``Code/ok``.
    public var isFailure: Bool {
        code != .ok
    }

    /// The code, SIP response and message joined into one line.
    public var description: String {
        var parts = ["\(code)"]
        if let sipStatus {
            parts.append("SIP \(sipStatus) \(sipReason)")
        }
        if let endReason {
            parts.append("\(endReason)")
        }
        if !message.isEmpty {
            parts.append(message)
        }
        return parts.joined(separator: ": ")
    }

    /// The category of a failed BaresipKit operation.
    ///
    /// The codes mirror the status codes of the C core one to one, so a code seen in a log line
    /// has the same meaning in Swift.
    public enum Code: Int, Sendable, Codable {
        /// The operation succeeded.
        case ok = 0
        /// An argument was missing, empty or malformed.
        case invalidArgument = 1
        /// The engine, account or call is not in a state that allows the operation.
        case invalidState = 2
        /// No account, call or message with the given identifier exists.
        case notFound = 3
        /// The core could not allocate memory.
        case noMemory = 4
        /// The operation is not available in this build or for this call.
        case unsupported = 5
        /// The resource is busy, for example the maximum number of calls is reached.
        case busy = 6
        /// The operation did not finish in time.
        case timeout = 7
        /// A network or transport error occurred.
        case network = 8
        /// The TLS handshake or certificate validation failed.
        case tls = 9
        /// The server rejected the credentials.
        case authentication = 10
        /// The SIP transaction failed; ``BaresipError/sipStatus`` holds the response code.
        case sip = 11
        /// Audio or video setup failed.
        case media = 12
        /// A buffer supplied to the core was too small.
        case bufferTooSmall = 13
        /// An unexpected internal error occurred.
        case internalError = 14
    }
}

/// Why a call ended other than by a hang-up or a failure; see ``BaresipError/endReason``.
public enum BaresipCallEndReason: Sendable, Equatable {
    /// Another device answered the call (`Reason: SIP;cause=200`).
    case answeredElsewhere
    /// Another device declined the call (`Reason: SIP;cause=600` or `603`).
    case declinedElsewhere
    /// Another call took the conversation over: the server replaced this call with a new INVITE
    /// (`Replaces`), or the other side transferred it and the engine followed the transfer. The
    /// new call's ``BaresipCallInfo/replacesCallID`` is this call. Do not show the call as ended.
    case replaced
}
