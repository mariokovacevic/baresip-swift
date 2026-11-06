import Foundation
import BaresipKit

/// The push tokens of an app, encoded as `Contact` header parameters for the registrar.
///
/// The parameters follow the format used by push-capable SIP servers such as Flexisip and
/// Kamailio's push module: `app-id`, `pn-type`, `pn-tok` (hex tokens joined as
/// `remote&voip`), `pn-silent`, `pn-timeout` and an optional `pn-channel`.
public struct BaresipPushTokens: Sendable, Equatable {
    /// The app's bundle identifier, sent as `app-id`.
    public var appID: String
    /// The APNs token for regular remote notifications.
    public var remoteToken: Data?
    /// The PushKit VoIP token.
    public var voipToken: Data?
    /// The push platform, sent as `pn-type`.
    public var platform: String
    /// Whether the server should send silent pushes, sent as `pn-silent`.
    public var silent: Bool
    /// The push timeout the server should use, sent as `pn-timeout`.
    public var timeout: Int
    /// An optional channel, sent as `pn-channel`.
    public var channel: String?

    /// Creates push token settings.
    ///
    /// - Parameters:
    ///   - appID: The bundle identifier.
    ///   - remoteToken: The APNs token.
    ///   - voipToken: The PushKit VoIP token.
    ///   - platform: The push platform.
    ///   - silent: Whether pushes are silent.
    ///   - timeout: The push timeout.
    ///   - channel: An optional channel.
    public init(appID: String, remoteToken: Data? = nil, voipToken: Data? = nil,
                platform: String = "apple", silent: Bool = true, timeout: Int = 0,
                channel: String? = nil) {
        self.appID = appID
        self.remoteToken = remoteToken
        self.voipToken = voipToken
        self.platform = platform
        self.silent = silent
        self.timeout = timeout
        self.channel = channel
    }

    /// Both tokens in hex, joined as `<remote>:remote&<voip>:voip`; empty without tokens.
    public var combinedToken: String {
        var parts: [String] = []
        if let remoteToken {
            parts.append(Self.hex(remoteToken) + ":remote")
        }
        if let voipToken {
            parts.append(Self.hex(voipToken) + ":voip")
        }
        return parts.joined(separator: "&")
    }

    /// The `Contact` parameters for `BaresipEngine.updateContactParameters(accountID:parameters:reregisterNow:)`.
    public var contactParameters: [BaresipContactParameter] {
        var parameters = [
            BaresipContactParameter("app-id", appID),
            BaresipContactParameter("pn-type", platform),
        ]
        let token = combinedToken
        if !token.isEmpty {
            parameters.append(BaresipContactParameter("pn-tok", token))
        }
        parameters.append(BaresipContactParameter("pn-silent", silent ? "1" : "0"))
        parameters.append(BaresipContactParameter("pn-timeout", String(timeout)))
        if let channel {
            parameters.append(BaresipContactParameter("pn-channel", channel))
        }
        return parameters
    }

    static func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}
