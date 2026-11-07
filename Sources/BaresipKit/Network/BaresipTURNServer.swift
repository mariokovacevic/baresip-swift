/// A TURN relay used by ICE.
///
/// The URI selects the transport: `turn:host:3478` (UDP), `turn:host:3478?transport=tcp`
/// or `turns:host:5349` (TLS).
public struct BaresipTURNServer: Hashable, Sendable, Codable {
    /// The TURN URI.
    public let uri: String
    /// The TURN username, if the server needs one.
    public let username: String?
    /// The TURN password, if the server needs one.
    public let password: String?

    /// Creates a TURN server entry.
    ///
    /// - Parameters:
    ///   - uri: The TURN URI.
    ///   - username: The username.
    ///   - password: The password.
    public init(uri: String, username: String? = nil, password: String? = nil) {
        self.uri = uri
        self.username = username
        self.password = password
    }
}

/// The previous name of ``BaresipTURNServer``.
@available(*, deprecated, renamed: "BaresipTURNServer")
public typealias TURNServer = BaresipTURNServer
