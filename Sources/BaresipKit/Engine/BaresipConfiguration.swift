import Foundation

/// Engine-wide settings, passed to ``BaresipEngine/init(configuration:)``.
///
/// The defaults suit a typical iOS VoIP app; most apps only change ``userAgent`` and ``tls``.
public struct BaresipConfiguration: Sendable, Equatable {
    /// The `User-Agent` header value.
    public var userAgent: String
    /// The instance identifier sent as `+sip.instance` (RFC 5626). Keep it stable per install.
    public var instanceUUID: UUID
    /// The network interface to bind to, or `nil` for all interfaces.
    public var networkInterface: String?
    /// The baresip modules to load.
    public var modules: [String]
    /// Extra lines appended to the generated baresip configuration.
    public var extraConfiguration: String?
    /// Whether IPv6 addresses are used.
    public var ipv6: Bool
    /// The local UDP port range for RTP.
    public var rtpPortRange: ClosedRange<UInt16>
    /// The maximum number of simultaneous calls.
    public var maxCalls: Int
    /// Audio settings.
    public var audio: BaresipAudioConfiguration
    /// Video settings.
    public var video: BaresipVideoConfiguration
    /// TLS settings.
    public var tls: BaresipTLSConfiguration
    /// The lowest log level passed to the log handler.
    public var logLevel: BaresipLogLevel
    /// Whether full SIP messages are logged, with credentials redacted.
    public var logSIPTrace: Bool
    /// Whether ICE uses relayed candidates only.
    public var iceRelayOnly: Bool
    /// Whether the video bitrate follows RTCP loss reports.
    public var videoAdaptiveBitrate: Bool
    /// The lowest video bitrate, in bits per second, that adaptation goes down to.
    public var videoMinimumBitrate: Int

    /// The modules loaded by default: G.711, Opus, L16, ICE, TURN, STUN, SRTP, DTLS-SRTP,
    /// RTCP summaries, AudioUnit and the test video source.
    public static let defaultModules: [String] = [
        "g711", "opus", "l16", "auconv", "auresamp",
        "ice", "turn", "stun", "srtp", "dtls_srtp", "rtcpsummary",
        "audiounit", "fakevideo",
    ]

    /// Creates engine settings.
    ///
    /// - Parameters:
    ///   - userAgent: The `User-Agent` header value.
    ///   - instanceUUID: The stable instance identifier.
    ///   - networkInterface: The interface to bind to.
    ///   - modules: The baresip modules to load.
    ///   - extraConfiguration: Extra baresip configuration lines.
    ///   - ipv6: Whether IPv6 is used.
    ///   - rtpPortRange: The RTP port range.
    ///   - maxCalls: The maximum number of simultaneous calls.
    ///   - audio: Audio settings.
    ///   - video: Video settings.
    ///   - tls: TLS settings.
    ///   - logLevel: The lowest log level reported.
    ///   - logSIPTrace: Whether SIP messages are logged.
    ///   - iceRelayOnly: Whether ICE uses relays only.
    ///   - videoAdaptiveBitrate: Whether the video bitrate adapts to loss.
    ///   - videoMinimumBitrate: The lowest adaptive video bitrate.
    public init(userAgent: String = "BaresipKit", instanceUUID: UUID = UUID(),
                networkInterface: String? = nil,
                modules: [String] = BaresipConfiguration.defaultModules,
                extraConfiguration: String? = nil, ipv6: Bool = true,
                rtpPortRange: ClosedRange<UInt16> = 10000...20000, maxCalls: Int = 4,
                audio: BaresipAudioConfiguration = BaresipAudioConfiguration(),
                video: BaresipVideoConfiguration = BaresipVideoConfiguration(),
                tls: BaresipTLSConfiguration = BaresipTLSConfiguration(),
                logLevel: BaresipLogLevel = .info, logSIPTrace: Bool = false,
                iceRelayOnly: Bool = false,
                videoAdaptiveBitrate: Bool = true,
                videoMinimumBitrate: Int = 150_000) {
        self.userAgent = userAgent
        self.instanceUUID = instanceUUID
        self.networkInterface = networkInterface
        self.modules = modules
        self.extraConfiguration = extraConfiguration
        self.ipv6 = ipv6
        self.rtpPortRange = rtpPortRange
        self.maxCalls = maxCalls
        self.audio = audio
        self.video = video
        self.tls = tls
        self.logLevel = logLevel
        self.logSIPTrace = logSIPTrace
        self.iceRelayOnly = iceRelayOnly
        self.videoAdaptiveBitrate = videoAdaptiveBitrate
        self.videoMinimumBitrate = videoMinimumBitrate
    }
}
