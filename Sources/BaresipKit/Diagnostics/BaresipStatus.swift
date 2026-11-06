/// The category of a failed BaresipKit operation.
///
/// Every ``BaresipError`` carries one of these codes. They mirror the status codes of the
/// C core one to one, so a code seen in a log line has the same meaning in Swift.
public enum BaresipStatus: Int, Sendable, Codable {
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
