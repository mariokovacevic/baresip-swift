import Foundation
import SwiftUI
import BaresipKit
import BaresipKitCallKit
import BaresipKitLiveCommunication

/// Adapts the sample to a particular SIP deployment without changing its code.
///
/// The sample uses ``DefaultAppProfile``. A git-ignored `Local/` folder can add a class named
/// `BSKLocalAppProfile` that conforms to this protocol; `project.local.yml` compiles it in and
/// the sample picks it up at launch (see `Examples/SampleApp/README.md`).
@MainActor
protocol AppProfile: AnyObject, Sendable {
    init()

    /// Changes the engine configuration before the engine starts.
    func configure(_ configuration: inout BaresipConfiguration)

    /// Changes the account configuration before the account is registered.
    func configure(_ account: inout BaresipAccountConfiguration)

    /// Changes the CallKit configuration before the adapter is created.
    func configure(_ callKit: inout BaresipCallKitConfiguration)

    /// Changes the LiveCommunicationKit configuration before the adapter is created.
    func configure(_ liveCommunication: inout BaresipLiveCommunicationConfiguration)

    /// The `app-id` push parameter.
    var pushAppID: String { get }

    /// The caller's SIP URI or user and display name in a VoIP push payload.
    nonisolated static func caller(in payload: [AnyHashable: Any]) -> (uri: String?, name: String?)

    /// An extra section at the top of the Account screen, or `nil`.
    func accountSection(model: CallModel) -> AnyView?
}

extension AppProfile {
    func configure(_ liveCommunication: inout BaresipLiveCommunicationConfiguration) {}
}

/// The sample's own settings.
final class DefaultAppProfile: AppProfile {
    init() {}

    func configure(_ configuration: inout BaresipConfiguration) {}

    func configure(_ account: inout BaresipAccountConfiguration) {}

    func configure(_ callKit: inout BaresipCallKitConfiguration) {}

    var pushAppID: String {
        Bundle.main.bundleIdentifier ?? "com.example.BaresipKitSample"
    }

    nonisolated static func caller(in payload: [AnyHashable: Any]) -> (uri: String?, name: String?) {
        let from = payload["from"] as? String
        return (from, from)
    }

    func accountSection(model: CallModel) -> AnyView? {
        nil
    }
}

enum AppProfiles {
    private static let localClassName = "BSKLocalAppProfile"

    /// The local profile when one is compiled in, otherwise the default one.
    @MainActor static let current: AppProfile = {
        if let type = NSClassFromString(localClassName) as? AppProfile.Type {
            return type.init()
        }
        return DefaultAppProfile()
    }()
}
