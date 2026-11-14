import Foundation
import BaresipKit

struct SIPSettings: Codable, Equatable {
    var domain = ""
    var port = ""
    var transport: BaresipTransport = .tls
    var username = ""
    var authUser = ""
    var displayName = ""
    var outboundProxy = ""
    var mediaEncryption: BaresipMediaEncryption = .srtpOptional
    var pins = ""
    var natMode: BaresipNATTraversal = .none
    var stunURI = ""
    var turnURI = ""
    var turnUser = ""
    var previewAudio = true
    /// Whether the account stays registered in the background, so a VoIP push can announce a call.
    var reachableInBackground = false
    /// Whether a call that rings with video in the background shows a notification with its picture.
    var ringPicture = true
    var rtcpMux = true
    var pinhole = true
    var pictureUpdateOverInfo = true
    var dtmfMode: BaresipDTMFMode = .sipInfo
    /// Seconds without RTP before an established call ends; 0 never ends it.
    var rtpTimeoutSeconds = 30
    var sipOutbound = false
    var registerExpiresSeconds = 600
    var acceptTransfers = true
    /// Comma separated codec names in order of preference; empty uses the engine's list.
    var audioCodecs = ""
    var videoCodecs = ""
    /// Settings the engine reads when it starts; changing them restarts it.
    var engine = EngineOptions()

    var useICE: Bool {
        natMode == .ice
    }

    var isComplete: Bool {
        !domain.trimmed.isEmpty && !username.trimmed.isEmpty
    }

    var transportName: String {
        switch transport {
        case .udp: return "udp"
        case .tcp: return "tcp"
        case .tls: return "tls"
        case .wss: return "wss"
        }
    }

    var aor: String {
        "sip:\(username.trimmed)@\(domain.trimmed)"
    }

    var registrar: String {
        let host = domain.trimmed
        let trimmedPort = port.trimmed
        return "sip:\(host)\(trimmedPort.isEmpty ? "" : ":\(trimmedPort)");transport=\(transportName)"
    }

    var proxy: String? {
        let raw = outboundProxy.trimmed
        guard !raw.isEmpty else { return nil }
        if raw.hasPrefix("sip:") || raw.hasPrefix("sips:") {
            return raw
        }
        return "sip:\(raw);transport=\(transportName);lr"
    }

    var pinList: [String] {
        pins.split(whereSeparator: { $0 == "\n" || $0 == "," || $0 == " " })
            .map { String($0).trimmed }
            .filter { !$0.isEmpty }
    }

    static func codecList(_ text: String) -> [String] {
        text.split(whereSeparator: { $0 == "," || $0 == " " || $0 == "\n" })
            .map { String($0).trimmed }
            .filter { !$0.isEmpty }
    }
}

/// Engine settings exposed for testing. Zero means the engine or profile default.
struct EngineOptions: Codable, Equatable {
    var ipv6 = true
    var iceRelayOnly = false
    var videoHeight = 0
    var videoFramesPerSecond = 0
    var videoBitrateKbps = 0
    var adaptiveBitrate = true

    /// Video sizes offered in the Account screen, as height; the width follows at 4:3.
    static let videoHeights = [0, 240, 288, 480, 720]
    static let videoFrameRates = [0, 10, 15, 25, 30]
    static let videoBitrates = [0, 300, 600, 1000, 1500, 2500]

    static func width(forHeight height: Int) -> Int {
        height == 288 ? 352 : (height == 720 ? 1280 : height * 4 / 3)
    }

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = EngineOptions()
        ipv6 = try values.decodeIfPresent(Bool.self, forKey: .ipv6) ?? defaults.ipv6
        iceRelayOnly = try values.decodeIfPresent(Bool.self, forKey: .iceRelayOnly) ?? defaults.iceRelayOnly
        videoHeight = try values.decodeIfPresent(Int.self, forKey: .videoHeight) ?? defaults.videoHeight
        videoFramesPerSecond = try values.decodeIfPresent(Int.self, forKey: .videoFramesPerSecond)
            ?? defaults.videoFramesPerSecond
        videoBitrateKbps = try values.decodeIfPresent(Int.self, forKey: .videoBitrateKbps)
            ?? defaults.videoBitrateKbps
        adaptiveBitrate = try values.decodeIfPresent(Bool.self, forKey: .adaptiveBitrate)
            ?? defaults.adaptiveBitrate
    }
}

extension SIPSettings {
    /// Keys of settings that older versions saved and this one replaced.
    private enum LegacyKeys: String, CodingKey {
        case useICE
        case dtmfOverSIPInfo
    }

    /// Reads saved settings; a missing key keeps its default, so adding a setting never drops
    /// a saved account.
    init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        func read<T: Decodable>(_ key: CodingKeys, _ value: inout T) throws {
            if let decoded = try values.decodeIfPresent(T.self, forKey: key) {
                value = decoded
            }
        }
        try read(.domain, &domain)
        try read(.port, &port)
        try read(.transport, &transport)
        try read(.username, &username)
        try read(.authUser, &authUser)
        try read(.displayName, &displayName)
        try read(.outboundProxy, &outboundProxy)
        try read(.mediaEncryption, &mediaEncryption)
        try read(.pins, &pins)
        try read(.natMode, &natMode)
        try read(.stunURI, &stunURI)
        try read(.turnURI, &turnURI)
        try read(.turnUser, &turnUser)
        try read(.previewAudio, &previewAudio)
        try read(.reachableInBackground, &reachableInBackground)
        try read(.ringPicture, &ringPicture)
        try read(.rtcpMux, &rtcpMux)
        try read(.pinhole, &pinhole)
        try read(.pictureUpdateOverInfo, &pictureUpdateOverInfo)
        try read(.dtmfMode, &dtmfMode)
        try read(.rtpTimeoutSeconds, &rtpTimeoutSeconds)
        try read(.sipOutbound, &sipOutbound)
        try read(.registerExpiresSeconds, &registerExpiresSeconds)
        try read(.acceptTransfers, &acceptTransfers)
        try read(.audioCodecs, &audioCodecs)
        try read(.videoCodecs, &videoCodecs)
        try read(.engine, &engine)

        let legacy = try decoder.container(keyedBy: LegacyKeys.self)
        if !values.contains(.natMode), try legacy.decodeIfPresent(Bool.self, forKey: .useICE) == true {
            natMode = .ice
        }
        if !values.contains(.dtmfMode),
           let overInfo = try legacy.decodeIfPresent(Bool.self, forKey: .dtmfOverSIPInfo) {
            dtmfMode = overInfo ? .sipInfo : .auto
        }
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
