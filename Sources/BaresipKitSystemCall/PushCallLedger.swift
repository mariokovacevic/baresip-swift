import Foundation
import BaresipKit

package enum PushMatch: Comparable {
    case mismatch
    case anyCaller
    case user
    case userAndHost

    package static func between(push: String?, invite: String, matchesPushWithoutCaller: Bool) -> PushMatch {
        let pushed = SIPIdentity(push ?? "")
        guard !pushed.isEmpty else {
            return matchesPushWithoutCaller ? .anyCaller : .mismatch
        }
        let caller = SIPIdentity(invite)
        guard pushed.user == caller.user else { return .mismatch }
        if pushed.host.isEmpty {
            return .user
        }
        return pushed.host == caller.host ? .userAndHost : .mismatch
    }
}

package struct PushCallLedger {
    package struct Announcement: Equatable {
        package let uuid: UUID
        package let remoteURI: String?
        package let hasVideo: Bool
        package var namedByServer = true

        package init(uuid: UUID, remoteURI: String?, hasVideo: Bool, namedByServer: Bool = true) {
            self.uuid = uuid
            self.remoteURI = remoteURI
            self.hasVideo = hasVideo
            self.namedByServer = namedByServer
        }
    }

    package enum Resolution: Equatable {
        case unannounced
        case announced(Announcement, callerConfirmed: Bool)
        case declined
    }

    private struct Entry {
        let announcement: Announcement
        var declinedUntil: ContinuousClock.Instant?
    }

    package let matchesPushWithoutCaller: Bool
    private var entries: [Entry] = []
    private var ringing: [BaresipCallID: (remoteURI: String, uuid: UUID?)] = [:]

    package init(matchesPushWithoutCaller: Bool) {
        self.matchesPushWithoutCaller = matchesPushWithoutCaller
    }

    package func duplicatesRingingCall(remoteURI: String?, namedByServer: Bool = false) -> Bool {
        ringing.values.contains { call in
            guard !namedByServer || call.uuid == nil else { return false }
            return strength(of: remoteURI, against: call.remoteURI) != .mismatch
        }
    }

    package func isAnnounced(_ uuid: UUID) -> Bool {
        pendingIndex(of: uuid) != nil
    }

    package func knows(_ uuid: UUID) -> Bool {
        entries.contains { $0.announcement.uuid == uuid }
    }

    package mutating func add(_ announcement: Announcement, now: ContinuousClock.Instant) {
        forgetExpiredDeclines(now: now)
        entries.append(Entry(announcement: announcement))
    }

    @discardableResult
    package mutating func discard(_ uuid: UUID) -> Bool {
        guard let index = pendingIndex(of: uuid) else { return false }
        entries.remove(at: index)
        return true
    }

    @discardableResult
    package mutating func decline(_ uuid: UUID, until deadline: ContinuousClock.Instant) -> Bool {
        guard let index = pendingIndex(of: uuid) else { return false }
        entries[index].declinedUntil = deadline
        return true
    }

    package mutating func resolve(invite: String, uuid: UUID? = nil, now: ContinuousClock.Instant) -> Resolution {
        forgetExpiredDeclines(now: now)
        if let uuid, entries.contains(where: { $0.announcement.uuid == uuid }) {
            return resolve(uuid: uuid)
        }
        var best: (index: Int, match: PushMatch)?
        for (index, entry) in entries.enumerated() where uuid == nil || !entry.announcement.namedByServer {
            let candidate = strength(of: entry.announcement.remoteURI, against: invite)
            if candidate > best?.match ?? .mismatch {
                best = (index, candidate)
            }
        }
        guard let best else { return .unannounced }
        let entry = entries.remove(at: best.index)
        if entry.declinedUntil != nil {
            return .declined
        }
        return .announced(entry.announcement, callerConfirmed: best.match == .userAndHost)
    }

    private mutating func resolve(uuid: UUID) -> Resolution {
        guard let index = entries.firstIndex(where: { $0.announcement.uuid == uuid }) else { return .unannounced }
        let entry = entries.remove(at: index)
        if entry.declinedUntil != nil {
            return .declined
        }
        return .announced(entry.announcement, callerConfirmed: true)
    }

    package mutating func startedRinging(_ call: BaresipCallID, remoteURI: String, uuid: UUID? = nil) {
        ringing[call] = (remoteURI, uuid)
    }

    package mutating func stoppedRinging(_ call: BaresipCallID) {
        ringing[call] = nil
    }

    package mutating func removeAll() {
        entries.removeAll()
        ringing.removeAll()
    }

    package static func sendsCamera(pushHadVideo: Bool, inviteHasVideo: Bool, sendsCameraOnAnswer: Bool) -> Bool {
        pushHadVideo && inviteHasVideo && sendsCameraOnAnswer
    }

    package static func callerName(inviteURI: String, inviteDisplayName: String,
                                   replacingAnnouncedName: Bool) -> String? {
        if !inviteDisplayName.isEmpty {
            return inviteDisplayName
        }
        return replacingAnnouncedName ? inviteURI : nil
    }

    private func pendingIndex(of uuid: UUID) -> Int? {
        entries.firstIndex { $0.announcement.uuid == uuid && $0.declinedUntil == nil }
    }

    private mutating func forgetExpiredDeclines(now: ContinuousClock.Instant) {
        entries.removeAll { entry in
            guard let deadline = entry.declinedUntil else { return false }
            return deadline <= now
        }
    }

    private func strength(of push: String?, against invite: String) -> PushMatch {
        PushMatch.between(push: push, invite: invite, matchesPushWithoutCaller: matchesPushWithoutCaller)
    }
}
