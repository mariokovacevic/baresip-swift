import Foundation
import BaresipKit

enum PushMatch: Comparable {
    case mismatch
    case anyCaller
    case user
    case userAndHost

    static func between(push: String?, invite: String, matchesPushWithoutCaller: Bool) -> PushMatch {
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

struct PushCallLedger {
    struct Announcement: Equatable {
        let uuid: UUID
        let remoteURI: String?
        let hasVideo: Bool
    }

    enum Resolution: Equatable {
        case unannounced
        case announced(Announcement, callerConfirmed: Bool)
        case declined
    }

    private struct Entry {
        let announcement: Announcement
        var declinedUntil: ContinuousClock.Instant?
    }

    let matchesPushWithoutCaller: Bool
    private var entries: [Entry] = []
    private var ringing: [BaresipCallID: String] = [:]

    init(matchesPushWithoutCaller: Bool) {
        self.matchesPushWithoutCaller = matchesPushWithoutCaller
    }

    func duplicatesRingingCall(remoteURI: String?) -> Bool {
        ringing.values.contains { strength(of: remoteURI, against: $0) != .mismatch }
    }

    func isAnnounced(_ uuid: UUID) -> Bool {
        pendingIndex(of: uuid) != nil
    }

    mutating func add(_ announcement: Announcement, now: ContinuousClock.Instant) {
        forgetExpiredDeclines(now: now)
        entries.append(Entry(announcement: announcement))
    }

    @discardableResult
    mutating func discard(_ uuid: UUID) -> Bool {
        guard let index = pendingIndex(of: uuid) else { return false }
        entries.remove(at: index)
        return true
    }

    @discardableResult
    mutating func decline(_ uuid: UUID, until deadline: ContinuousClock.Instant) -> Bool {
        guard let index = pendingIndex(of: uuid) else { return false }
        entries[index].declinedUntil = deadline
        return true
    }

    mutating func resolve(invite: String, now: ContinuousClock.Instant) -> Resolution {
        forgetExpiredDeclines(now: now)
        var best: (index: Int, match: PushMatch)?
        for (index, entry) in entries.enumerated() {
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

    mutating func startedRinging(_ call: BaresipCallID, remoteURI: String) {
        ringing[call] = remoteURI
    }

    mutating func stoppedRinging(_ call: BaresipCallID) {
        ringing[call] = nil
    }

    mutating func removeAll() {
        entries.removeAll()
        ringing.removeAll()
    }

    static func sendsCamera(pushHadVideo: Bool, inviteHasVideo: Bool, sendsCameraOnAnswer: Bool) -> Bool {
        pushHadVideo && inviteHasVideo && sendsCameraOnAnswer
    }

    static func callerName(inviteURI: String, inviteDisplayName: String, replacingAnnouncedName: Bool) -> String? {
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
