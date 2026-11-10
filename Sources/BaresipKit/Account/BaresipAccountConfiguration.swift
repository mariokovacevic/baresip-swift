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
    /// Whether SIP Outbound (RFC 5626) is used.
    public var sipOutbound: Bool
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
    /// Whether requests for a new video picture are also sent as SIP INFO (RFC 5168).
    ///
    /// When the received video is damaged or starts without a key frame, the engine asks the
    /// peer for a new picture with RTCP PLI or FIR. Some endpoints, such as door stations,
    /// react only to a SIP INFO `picture_fast_update` request. Incoming requests of that kind
    /// are always answered. Off by default.
    public var pictureUpdateOverSIPInfo: Bool
    /// Headers of incoming INVITEs to keep, such as `X-Device-ID`, read with
    /// `BaresipEngine.incomingHeader(_:callID:)`.
    public var incomingHeaders: [String]

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
    ///   - sipOutbound: Whether SIP Outbound is used.
    ///   - mediaEncryption: Media encryption.
    ///   - nat: NAT traversal settings.
    ///   - dtmfMode: How DTMF is sent.
    ///   - contactParameters: Extra `Contact` parameters.
    ///   - audioCodecs: Account audio codecs.
    ///   - videoCodecs: Account video codecs.
    ///   - answerEarlyMedia: Whether incoming calls are previewed automatically.
    ///   - acceptTransfers: Whether incoming transfers are followed.
    ///   - pictureUpdateOverSIPInfo: Whether picture update requests are also sent as SIP INFO.
    ///   - incomingHeaders: Headers of incoming INVITEs to keep.
    public init(aor: String, displayName: String? = nil, registrar: String? = nil,
                outboundProxy: String? = nil, transport: BaresipTransport = .tls,
                authUser: String? = nil, authPassword: String? = nil,
                registerExpires: Duration = .seconds(600), sipOutbound: Bool = false,
                mediaEncryption: BaresipMediaEncryption = .srtpOptional,
                nat: BaresipNATConfiguration = BaresipNATConfiguration(),
                dtmfMode: BaresipDTMFMode = .auto,
                contactParameters: [BaresipContactParameter] = [],
                audioCodecs: [String] = [], videoCodecs: [String] = [],
                answerEarlyMedia: Bool = false, acceptTransfers: Bool = true,
                pictureUpdateOverSIPInfo: Bool = false, incomingHeaders: [String] = []) {
        self.aor = aor
        self.displayName = displayName
        self.registrar = registrar
        self.outboundProxy = outboundProxy
        self.transport = transport
        self.authUser = authUser
        self.authPassword = authPassword
        self.registerExpires = registerExpires
        self.sipOutbound = sipOutbound
        self.mediaEncryption = mediaEncryption
        self.nat = nat
        self.dtmfMode = dtmfMode
        self.contactParameters = contactParameters
        self.audioCodecs = audioCodecs
        self.videoCodecs = videoCodecs
        self.answerEarlyMedia = answerEarlyMedia
        self.acceptTransfers = acceptTransfers
        self.pictureUpdateOverSIPInfo = pictureUpdateOverSIPInfo
        self.incomingHeaders = incomingHeaders
    }

    /// Checks the settings without contacting a server.
    ///
    /// ``BaresipEngine/addAccount(_:)`` calls this before adding the account.
    ///
    /// - Throws: ``BaresipError`` with ``BaresipError/Code/invalidArgument`` when the address of
    ///   record is not a `sip:` or `sips:` URI with a user and a domain, a URI or the
    ///   authentication user contains characters that cannot be sent, the authentication user
    ///   is empty, more than one TURN server is given, or a contact parameter is not a valid
    ///   SIP token.
    public func validate() throws {
        guard let scheme = ["sips:", "sip:"].first(where: { aor.hasPrefix($0) }) else {
            throw Self.invalid("aor must start with sip: or sips:")
        }
        let address = aor.dropFirst(scheme.count).split(separator: "@", maxSplits: 1,
                                                        omittingEmptySubsequences: false)
        guard address.count == 2, !address[0].isEmpty, !address[1].isEmpty else {
            throw Self.invalid("aor must contain user@domain")
        }
        guard Self.isSendable(aor, forbidden: "\"<>;? ") else {
            throw Self.invalid("aor must not contain quotes, angle brackets, ';', '?' or spaces")
        }
        for uri in [registrar, outboundProxy].compactMap(\.self) {
            guard uri.hasPrefix("sip:") || uri.hasPrefix("sips:"), Self.isSendable(uri, forbidden: "\"<>? ") else {
                throw Self.invalid("registrar and outbound proxy must be sip: or sips: URIs")
            }
        }
        if let authUser, authUser.isEmpty || !Self.isSendable(authUser, forbidden: "") {
            throw Self.invalid("authUser must not be empty or contain control characters")
        }
        guard nat.turnServers.count <= 1 else {
            throw Self.invalid("at most one TURN server is supported")
        }
        _ = try BaresipEngine.encodeContactParameters(contactParameters)
    }

    private static func invalid(_ message: String) -> BaresipError {
        BaresipError(code: .invalidArgument, message: message)
    }

    private static func isSendable(_ text: String, forbidden: String) -> Bool {
        !text.unicodeScalars.contains { $0.value < 0x20 || $0.value == 0x7F || forbidden.unicodeScalars.contains($0) }
    }
}
