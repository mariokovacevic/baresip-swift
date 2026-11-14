import Foundation
import BaresipKit
import BaresipKitSwiftUI

/// DTMF the app sends on a call, such as a door code, and what came of it.
struct DTMFState: Equatable {
    var request: DTMFRequest
    var sent = false
    var result: String?
}

/// What the screens show about one call: the SDK's call state plus the app's DTMF request.
struct CallRow: Identifiable, Equatable {
    let id: BaresipCallID
    var remote: String
    var state: BaresipCallState
    var outgoing: Bool
    var hasVideo: Bool
    var receivingVideo: Bool
    var sendingVideo: Bool
    var codec: String
    var connectedAt: Date?
    var uri: String
    var startedAt: Date
    var dtmf: DTMFRequest?
    var dtmfSent = false
    var dtmfResult: String?
    /// Whether another phone answered or declined the call while it rang here.
    var endedElsewhere: BaresipCallEndReason?

    @MainActor
    init(call: BaresipPhoneCall, dtmf: DTMFState?) {
        id = call.id
        remote = call.remoteDisplayName.isEmpty ? (call.remoteURI.isEmpty ? "…" : call.remoteURI) : call
            .remoteDisplayName
        state = call.state
        outgoing = call.isOutgoing
        hasVideo = call.hasVideo
        receivingVideo = call.isReceivingVideo
        sendingVideo = call.isSendingVideo
        codec = call.audioCodec
        connectedAt = call.connectedAt
        uri = call.remoteURI
        startedAt = call.startedAt
        self.dtmf = dtmf?.request
        dtmfSent = dtmf?.sent ?? false
        dtmfResult = dtmf?.result
        endedElsewhere = call.error?.endReason
    }

    var dtmfDigits: String {
        dtmf?.digits ?? ""
    }

    var title: String {
        CallRow.displayName(remote)
    }

    var initials: String {
        CallRow.initials(title)
    }

    var isHeld: Bool {
        state == .paused || state == .pausing
    }

    static func displayName(_ remote: String) -> String {
        var value = remote
        for scheme in ["sips:", "sip:", "tel:"] where value.hasPrefix(scheme) {
            value = String(value.dropFirst(scheme.count))
        }
        let user = value.prefix { $0 != "@" && $0 != ";" }
        return user.isEmpty ? remote : String(user)
    }

    static func initials(_ name: String) -> String {
        let words = name.split(whereSeparator: { $0 == " " || $0 == "." || $0 == "-" }).prefix(2)
        let letters = words.compactMap(\.first).map { String($0).uppercased() }.joined()
        return letters.isEmpty ? String(name.prefix(2)).uppercased() : letters
    }
}
