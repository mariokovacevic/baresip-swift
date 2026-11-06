/// The settings of one SIP account, passed to ``BaresipEngine/addAccount(_:)``.
///
/// ```swift
/// let account = BaresipAccountConfiguration(
///     aor: "sip:alice@example.com",
///     authPassword: password
/// )
/// let id = try await engine.addAccount(account)
/// try await engine.register(accountID: id)
/// ```
public struct BaresipAccountConfiguration: Sendable, Equatable {
    /// The address of record, for example `sip:alice@example.com`.
    public var aor: String
    /// The display name in the `From` header.
    public var displayName: String?
    /// The registrar URI, or `nil` to use the domain of ``aor``.
    public var registrar: String?
    /// An outbound proxy URI.
    public var outboundProxy: String?
    /// The SIP transport.
    public var transport: BaresipTransport
    /// The authentication user name, or `nil` to use the user part of ``aor``.
    public var authUser: String?
    /// The authentication password. It is passed to the core and never logged.
    public var authPassword: String?
    /// The requested registration lifetime.
    public var registerExpires: Duration
    /// The retry back-off range after a failed registration.
    public var registerRetry: ClosedRange<Duration>
    /// Whether SIP Outbound (RFC 5626) is used.
    public var sipOutbound: Bool
    /// Whether keep-alives are sent on the signalling connection.
    public var keepAlive: Bool
    /// Media encryption for calls of this account.
    public var mediaEncryption: BaresipMediaEncryption
    /// NAT traversal settings.
    public var nat: BaresipNATConfiguration
    /// How DTMF is sent.
    public var dtmfMode: BaresipDTMFMode
    /// Extra `Contact` header parameters, for example for push routing.
    public var contactParameters: [BaresipContactParameter]
    /// Audio codecs for this account, or empty for the engine's list.
    public var audioCodecs: [String]
    /// Video codecs for this account, or empty for the engine's list.
    public var videoCodecs: [String]
    /// Whether incoming calls start a receive-only early media preview automatically.
    public var answerEarlyMedia: Bool
    /// Whether incoming REFER requests are followed. When `false` they are declined.
    public var acceptTransfers: Bool

    /// Creates account settings.
    ///
    /// - Parameters:
    ///   - aor: The address of record.
    ///   - displayName: The display name.
    ///   - registrar: The registrar URI.
    ///   - outboundProxy: An outbound proxy URI.
    ///   - transport: The SIP transport.
    ///   - authUser: The authentication user name.
    ///   - authPassword: The authentication password.
    ///   - registerExpires: The registration lifetime.
    ///   - registerRetry: The retry back-off range.
    ///   - sipOutbound: Whether SIP Outbound is used.
    ///   - keepAlive: Whether keep-alives are sent.
    ///   - mediaEncryption: Media encryption.
    ///   - nat: NAT traversal settings.
    ///   - dtmfMode: How DTMF is sent.
    ///   - contactParameters: Extra `Contact` parameters.
    ///   - audioCodecs: Account audio codecs.
    ///   - videoCodecs: Account video codecs.
    ///   - answerEarlyMedia: Whether incoming calls are previewed automatically.
    ///   - acceptTransfers: Whether incoming transfers are followed.
    public init(aor: String, displayName: String? = nil, registrar: String? = nil,
                outboundProxy: String? = nil, transport: BaresipTransport = .tls,
                authUser: String? = nil, authPassword: String? = nil,
                registerExpires: Duration = .seconds(600),
                registerRetry: ClosedRange<Duration> = .seconds(2)...(.seconds(120)),
                sipOutbound: Bool = false, keepAlive: Bool = true,
                mediaEncryption: BaresipMediaEncryption = .srtpOptional,
                nat: BaresipNATConfiguration = BaresipNATConfiguration(),
                dtmfMode: BaresipDTMFMode = .auto,
                contactParameters: [BaresipContactParameter] = [],
                audioCodecs: [String] = [], videoCodecs: [String] = [],
                answerEarlyMedia: Bool = false, acceptTransfers: Bool = true) {
        self.aor = aor
        self.displayName = displayName
        self.registrar = registrar
        self.outboundProxy = outboundProxy
        self.transport = transport
        self.authUser = authUser
        self.authPassword = authPassword
        self.registerExpires = registerExpires
        self.registerRetry = registerRetry
        self.sipOutbound = sipOutbound
        self.keepAlive = keepAlive
        self.mediaEncryption = mediaEncryption
        self.nat = nat
        self.dtmfMode = dtmfMode
        self.contactParameters = contactParameters
        self.audioCodecs = audioCodecs
        self.videoCodecs = videoCodecs
        self.answerEarlyMedia = answerEarlyMedia
        self.acceptTransfers = acceptTransfers
    }

    /// Checks the settings without contacting a server.
    ///
    /// ``BaresipEngine/addAccount(_:)`` calls this before adding the account.
    ///
    /// - Throws: ``BaresipError`` with ``BaresipStatus/invalidArgument`` when the address of
    ///   record is not a `sip:` or `sips:` URI with a user and domain, the authentication
    ///   user is empty, or a contact parameter is not a valid SIP token.
    public func validate() throws {
        guard aor.hasPrefix("sip:") || aor.hasPrefix("sips:") else {
            throw BaresipError(status: .invalidArgument, message: "aor must start with sip: or sips:")
        }
        guard aor.contains("@") else {
            throw BaresipError(status: .invalidArgument, message: "aor must contain user@domain")
        }
        if let authUser, authUser.isEmpty {
            throw BaresipError(status: .invalidArgument, message: "authUser must not be empty")
        }
        _ = try BaresipEngine.encodeContactParameters(contactParameters)
    }
}
