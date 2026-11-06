import Foundation
import BaresipKitCore

public enum BaresipTransport: Int, Sendable, Codable {
    case udp = 0
    case tcp = 1
    case tls = 2
    case wss = 3

    var c: bsk_transport { bsk_transport(UInt32(rawValue)) }
}

public enum BaresipMediaEncryption: Int, Sendable, Codable {
    case none = 0
    case srtpOptional = 1
    case srtpMandatory = 2
    case dtlsSRTP = 3

    var c: bsk_media_encryption { bsk_media_encryption(UInt32(rawValue)) }
}

public enum BaresipNATTraversal: Int, Sendable, Codable {
    case none = 0
    case stun = 1
    case ice = 2

    var c: bsk_nat_traversal { bsk_nat_traversal(UInt32(rawValue)) }
}

public enum BaresipDTMFMode: Int, Sendable, Codable {
    case auto = 0
    case rtpEvent = 1
    case sipInfo = 2

    var c: bsk_dtmf_mode { bsk_dtmf_mode(UInt32(rawValue)) }
}

public struct ContactParameter: Hashable, Sendable, Codable {
    public let name: String
    public let value: String?

    public init(name: String, value: String?) {
        self.name = name
        self.value = value
    }

    public init(_ name: String, _ value: String) {
        self.init(name: name, value: value)
    }
}

public struct TURNServer: Hashable, Sendable, Codable {
    public let uri: String
    public let username: String?
    public let password: String?

    public init(uri: String, username: String? = nil, password: String? = nil) {
        self.uri = uri
        self.username = username
        self.password = password
    }
}

public struct BaresipNATConfiguration: Sendable, Equatable {
    public var mode: BaresipNATTraversal
    public var stunURI: String?
    public var turnServers: [TURNServer]
    public var symmetricRTPLatching: Bool
    public var rtpTimeout: Duration

    public init(mode: BaresipNATTraversal = .none, stunURI: String? = nil,
                turnServers: [TURNServer] = [], symmetricRTPLatching: Bool = true,
                rtpTimeout: Duration = .seconds(30)) {
        self.mode = mode
        self.stunURI = stunURI
        self.turnServers = turnServers
        self.symmetricRTPLatching = symmetricRTPLatching
        self.rtpTimeout = rtpTimeout
    }
}

public struct BaresipTLSConfiguration: Sendable, Equatable {
    public var caCertificatesPEM: Data?
    public var clientCertificatePEM: Data?
    public var pinnedSPKISHA256: [String]
    public var cipherList: String?
    public var minimumVersion: TLSVersion
    public var verifyServer: Bool

    public enum TLSVersion: Int, Sendable, Codable {
        case tls12 = 0x0303
        case tls13 = 0x0304
    }

    public init(caCertificatesPEM: Data? = nil, clientCertificatePEM: Data? = nil,
                pinnedSPKISHA256: [String] = [], cipherList: String? = nil,
                minimumVersion: TLSVersion = .tls12) {
        self.caCertificatesPEM = caCertificatesPEM
        self.clientCertificatePEM = clientCertificatePEM
        self.pinnedSPKISHA256 = pinnedSPKISHA256
        self.cipherList = cipherList
        self.minimumVersion = minimumVersion
        self.verifyServer = true
    }

    #if DEBUG
    public static func insecureSkippingServerVerification() -> BaresipTLSConfiguration {
        var c = BaresipTLSConfiguration()
        c.verifyServer = false
        return c
    }
    #endif
}

public struct BaresipAudioConfiguration: Sendable, Equatable {
    public var sourceModule: String
    public var sourceDevice: String?
    public var playerModule: String
    public var playerDevice: String?
    public var sampleRate: Int?
    public var channels: Int?
    public var packetTime: Duration
    public var jitterBufferRange: ClosedRange<Int>
    public var adaptiveJitterBuffer: Bool
    public var voiceProcessing: Bool
    public var codecs: [String]

    public init(sourceModule: String = "audiounit", sourceDevice: String? = nil,
                playerModule: String = "audiounit", playerDevice: String? = nil,
                sampleRate: Int? = nil, channels: Int? = nil,
                packetTime: Duration = .milliseconds(20),
                jitterBufferRange: ClosedRange<Int> = 40...200,
                adaptiveJitterBuffer: Bool = true, voiceProcessing: Bool = true,
                codecs: [String] = ["opus/48000/2", "PCMU/8000/1", "PCMA/8000/1"]) {
        self.sourceModule = sourceModule
        self.sourceDevice = sourceDevice
        self.playerModule = playerModule
        self.playerDevice = playerDevice
        self.sampleRate = sampleRate
        self.channels = channels
        self.packetTime = packetTime
        self.jitterBufferRange = jitterBufferRange
        self.adaptiveJitterBuffer = adaptiveJitterBuffer
        self.voiceProcessing = voiceProcessing
        self.codecs = codecs
    }
}

public struct BaresipVideoConfiguration: Sendable, Equatable {
    public var sourceModule: String
    public var sourceDevice: String?
    public var width: Int
    public var height: Int
    public var framesPerSecond: Int
    public var bitrate: Int
    public var codecs: [String]
    public var hardwareAcceleration: Bool

    public init(sourceModule: String = "bskcapture", sourceDevice: String? = nil,
                width: Int = 640, height: Int = 480, framesPerSecond: Int = 30,
                bitrate: Int = 800_000, codecs: [String] = ["H264"],
                hardwareAcceleration: Bool = true) {
        self.sourceModule = sourceModule
        self.sourceDevice = sourceDevice
        self.width = width
        self.height = height
        self.framesPerSecond = framesPerSecond
        self.bitrate = bitrate
        self.codecs = codecs
        self.hardwareAcceleration = hardwareAcceleration
    }
}

public struct BaresipConfiguration: Sendable, Equatable {
    public var userAgent: String
    public var instanceUUID: UUID
    public var networkInterface: String?
    public var modules: [String]
    public var extraConfiguration: String?
    public var ipv6: Bool
    public var rtpPortRange: ClosedRange<UInt16>
    public var maxCalls: Int
    public var audio: BaresipAudioConfiguration
    public var video: BaresipVideoConfiguration
    public var tls: BaresipTLSConfiguration
    public var logLevel: BaresipLogLevel
    public var logSIPTrace: Bool
    public var iceRelayOnly: Bool
    public var videoAdaptiveBitrate: Bool
    public var videoMinimumBitrate: Int

    public static let defaultModules: [String] = [
        "g711", "opus", "l16", "auconv", "auresamp",
        "ice", "turn", "stun", "srtp", "dtls_srtp", "rtcpsummary",
        "audiounit", "fakevideo",
    ]

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

public struct BaresipAccountConfiguration: Sendable, Equatable {
    public var aor: String
    public var displayName: String?
    public var registrar: String?
    public var outboundProxy: String?
    public var transport: BaresipTransport
    public var authUser: String?
    public var authPassword: String?
    public var registerExpires: Duration
    public var registerRetry: ClosedRange<Duration>
    public var sipOutbound: Bool
    public var keepAlive: Bool
    public var mediaEncryption: BaresipMediaEncryption
    public var nat: BaresipNATConfiguration
    public var dtmfMode: BaresipDTMFMode
    public var contactParameters: [ContactParameter]
    public var audioCodecs: [String]
    public var videoCodecs: [String]
    public var answerEarlyMedia: Bool
    public var acceptTransfers: Bool

    public init(aor: String, displayName: String? = nil, registrar: String? = nil,
                outboundProxy: String? = nil, transport: BaresipTransport = .tls,
                authUser: String? = nil, authPassword: String? = nil,
                registerExpires: Duration = .seconds(600),
                registerRetry: ClosedRange<Duration> = .seconds(2)...(.seconds(120)),
                sipOutbound: Bool = false, keepAlive: Bool = true,
                mediaEncryption: BaresipMediaEncryption = .srtpOptional,
                nat: BaresipNATConfiguration = BaresipNATConfiguration(),
                dtmfMode: BaresipDTMFMode = .auto,
                contactParameters: [ContactParameter] = [],
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

extension Duration {
    var wholeSeconds: UInt32 { UInt32(clamping: components.seconds) }
    var wholeMilliseconds: UInt32 {
        UInt32(clamping: components.seconds * 1000 + components.attoseconds / 1_000_000_000_000_000)
    }
}
