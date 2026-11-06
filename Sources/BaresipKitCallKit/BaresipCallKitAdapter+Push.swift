import CallKit
import Foundation
import BaresipKit

extension BaresipCallKitAdapter {
    /// Reports a call announced by a VoIP push to CallKit before its INVITE arrives.
    ///
    /// Call this from the PushKit handler: iOS requires a reported call for every VoIP push.
    /// When the INVITE arrives, it is matched by user and host against `remoteURI` (or taken
    /// as is when `remoteURI` is `nil`). If the user answers first, the call is answered as
    /// soon as it arrives. If no INVITE arrives within
    /// ``BaresipCallKitConfiguration/pushInviteTimeout``, the call is ended.
    ///
    /// - Parameters:
    ///   - uuid: A new UUID for the call.
    ///   - remoteURI: The caller's SIP URI from the push payload, if known.
    ///   - displayName: The caller's name to show.
    ///   - hasVideo: Whether the call is a video call.
    /// - Throws: The CallKit error when the system refuses the call, for example during Do Not Disturb.
    public func reportIncomingCallFromPush(uuid: UUID, remoteURI: String?, displayName: String?,
                                           hasVideo: Bool) async throws {
        lock.withLock {
            pendingIncoming[uuid] = (remoteURI, hasVideo)
        }
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: remoteURI ?? "unknown")
        update.localizedCallerName = displayName
        update.hasVideo = hasVideo
        try await provider.reportNewIncomingCall(with: uuid, update: update)
        let timeout = pushInviteTimeout
        Task { [weak self] in
            try? await Task.sleep(for: timeout)
            self?.expirePushCall(uuid)
        }
    }

    func expirePushCall(_ uuid: UUID) {
        let expired = lock.withLock { () -> Bool in
            guard pendingIncoming.removeValue(forKey: uuid) != nil else { return false }
            pendingAnswers.remove(uuid)
            return true
        }
        if expired {
            provider.reportCall(with: uuid, endedAt: Date(), reason: .failed)
        }
    }

    func takePendingPushCall(matching invite: String) -> UUID? {
        lock.withLock {
            let exact = pendingIncoming.first { entry in
                entry.value.remoteURI.map { !$0.isEmpty } == true
                    && Self.pushMatches(entry.value.remoteURI, invite: invite)
            }
            let wildcard = pendingIncoming.first { entry in
                (entry.value.remoteURI ?? "").isEmpty
            }
            guard let uuid = (exact ?? wildcard)?.key else { return nil }
            pendingIncoming[uuid] = nil
            return uuid
        }
    }

    static func normalizedSIPIdentity(_ uri: String) -> (user: String, host: String) {
        var value = uri.trimmingCharacters(in: .whitespaces).lowercased()
        if let open = value.firstIndex(of: "<"), let close = value.lastIndex(of: ">"), open < close {
            value = String(value[value.index(after: open) ..< close])
        }
        for scheme in ["sips:", "sip:", "tel:"] where value.hasPrefix(scheme) {
            value = String(value.dropFirst(scheme.count))
        }
        if let semicolon = value.firstIndex(of: ";") {
            value = String(value[..<semicolon])
        }
        let parts = value.split(separator: "@", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return (value, "") }
        let host = parts[1].split(separator: ":").first.map(String.init) ?? parts[1]
        return (parts[0], host)
    }

    static func pushMatches(_ pushURI: String?, invite: String) -> Bool {
        guard let pushURI, !pushURI.trimmingCharacters(in: .whitespaces).isEmpty else { return true }
        let push = normalizedSIPIdentity(pushURI)
        let call = normalizedSIPIdentity(invite)
        guard push.user == call.user else { return false }
        return push.host.isEmpty || call.host.isEmpty || push.host == call.host
    }
}
