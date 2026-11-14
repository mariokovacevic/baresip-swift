import Foundation
import BaresipKit

package struct SystemCallBook {
    package enum AnswerTarget: Equatable, Sendable {
        case call(BaresipCallID)
        case awaitsInvite
        case unknown
    }

    package struct PushReport: Equatable, Sendable {
        package let reported: UUID
        package let isDuplicate: Bool
    }

    package enum AnswerCamera: Equatable, Sendable {
        case requested(sendsCamera: Bool)
        case asConfigured

        package func sendsCamera(otherwise configured: Bool) -> Bool {
            switch self {
            case .requested(let sendsCamera): sendsCamera
            case .asConfigured: configured
            }
        }
    }

    package struct StateChange: Equatable, Sendable {
        package let uuid: UUID
        package let isOutgoing: Bool
    }

    package private(set) var abandonedStarts: Set<UUID> = []
    private var uuidByCall: [BaresipCallID: UUID] = [:]
    private var callByUUID: [UUID: BaresipCallID] = [:]
    private var pendingAnswers: Set<UUID> = []
    private var outgoing: Set<UUID> = []
    private var answerVideo: [UUID: Bool] = [:]
    private var startDestinations: [UUID: String] = [:]
    private var pushCalls: PushCallLedger

    package init(matchesPushWithoutCaller: Bool) {
        pushCalls = PushCallLedger(matchesPushWithoutCaller: matchesPushWithoutCaller)
    }

    package func uuid(for call: BaresipCallID) -> UUID? {
        uuidByCall[call]
    }

    package func call(for uuid: UUID) -> BaresipCallID? {
        callByUUID[uuid]
    }

    package mutating func announcePush(uuid pushedUUID: UUID?, remoteURI: String?, hasVideo: Bool,
                                       now: ContinuousClock.Instant) -> PushReport {
        let uuid = pushedUUID ?? UUID()
        if callByUUID[uuid] != nil || pushCalls.knows(uuid) {
            return PushReport(reported: UUID(), isDuplicate: true)
        }
        if pushCalls.duplicatesRingingCall(remoteURI: remoteURI, namedByServer: pushedUUID != nil) {
            return PushReport(reported: uuid, isDuplicate: true)
        }
        pushCalls.add(PushCallLedger.Announcement(uuid: uuid, remoteURI: remoteURI, hasVideo: hasVideo,
                                                  namedByServer: pushedUUID != nil),
                      now: now)
        return PushReport(reported: uuid, isDuplicate: false)
    }

    package mutating func expirePush(_ uuid: UUID) -> Bool {
        guard pushCalls.discard(uuid) else { return false }
        pendingAnswers.remove(uuid)
        return true
    }

    package mutating func forgetRefusedPush(_ uuid: UUID) -> BaresipCallID? {
        pushCalls.discard(uuid)
        pendingAnswers.remove(uuid)
        return callByUUID[uuid]
    }

    package mutating func resolveIncoming(_ call: BaresipCallID, remoteURI: String, announcedUUID: UUID?,
                                          now: ContinuousClock.Instant) -> PushCallLedger.Resolution {
        let resolution = pushCalls.resolve(invite: remoteURI, uuid: announcedUUID, now: now)
        if case .announced(let announcement, _) = resolution {
            bind(call, announcement.uuid)
            pushCalls.startedRinging(call, remoteURI: remoteURI, uuid: announcedUUID)
        }
        return resolution
    }

    package mutating func bindUnannounced(_ call: BaresipCallID, remoteURI: String, announcedUUID: UUID?) -> UUID {
        let uuid = announcedUUID.flatMap { callByUUID[$0] == nil && !pushCalls.knows($0) ? $0 : nil } ?? UUID()
        bind(call, uuid)
        pushCalls.startedRinging(call, remoteURI: remoteURI, uuid: announcedUUID)
        return uuid
    }

    package mutating func takePendingAnswer(_ uuid: UUID) -> Bool {
        pendingAnswers.remove(uuid) != nil
    }

    package mutating func stateChanged(_ call: BaresipCallID, to state: BaresipCallState) -> StateChange? {
        guard let uuid = uuidByCall[call] else { return nil }
        if state != .incoming, state != .earlyMedia {
            pushCalls.stoppedRinging(call)
        }
        return StateChange(uuid: uuid, isOutgoing: outgoing.contains(uuid))
    }

    package mutating func willStart(_ uuid: UUID, destination: String) {
        startDestinations[uuid] = destination
    }

    package mutating func startNotRequested(_ uuid: UUID) {
        startDestinations[uuid] = nil
    }

    package mutating func takeStartDestination(_ uuid: UUID) -> String? {
        startDestinations.removeValue(forKey: uuid)
    }

    package mutating func placed(_ call: BaresipCallID, uuid: UUID) -> Bool {
        if abandonedStarts.remove(uuid) != nil {
            return false
        }
        outgoing.insert(uuid)
        bind(call, uuid)
        return true
    }

    package mutating func startFailed(_ uuid: UUID) {
        abandonedStarts.remove(uuid)
    }

    package mutating func startTimedOut(_ uuid: UUID) -> BaresipCallID? {
        startDestinations[uuid] = nil
        guard let call = callByUUID[uuid] else {
            abandonedStarts.insert(uuid)
            return nil
        }
        return call
    }

    package mutating func answerTarget(_ uuid: UUID) -> AnswerTarget {
        if let call = callByUUID[uuid] {
            return .call(call)
        }
        guard pushCalls.isAnnounced(uuid) else { return .unknown }
        pendingAnswers.insert(uuid)
        return .awaitsInvite
    }

    package mutating func requestAnswer(_ uuid: UUID, sendsCamera: Bool) {
        answerVideo[uuid] = sendsCamera
    }

    package mutating func cancelAnswerRequest(_ uuid: UUID) {
        answerVideo[uuid] = nil
    }

    package mutating func takeAnswerCamera(_ uuid: UUID) -> AnswerCamera {
        answerVideo.removeValue(forKey: uuid).map { .requested(sendsCamera: $0) } ?? .asConfigured
    }

    package mutating func end(_ uuid: UUID, declineUntil deadline: ContinuousClock.Instant) -> BaresipCallID? {
        pendingAnswers.remove(uuid)
        pushCalls.decline(uuid, until: deadline)
        return callByUUID[uuid]
    }

    package mutating func unbind(_ call: BaresipCallID) -> UUID? {
        guard let uuid = uuidByCall.removeValue(forKey: call) else { return nil }
        callByUUID[uuid] = nil
        pendingAnswers.remove(uuid)
        outgoing.remove(uuid)
        answerVideo[uuid] = nil
        return uuid
    }

    package mutating func reset() -> [BaresipCallID] {
        let calls = Array(uuidByCall.keys)
        uuidByCall.removeAll()
        callByUUID.removeAll()
        pendingAnswers.removeAll()
        outgoing.removeAll()
        pushCalls.removeAll()
        answerVideo.removeAll()
        abandonedStarts.removeAll()
        startDestinations.removeAll()
        return calls
    }

    private mutating func bind(_ call: BaresipCallID, _ uuid: UUID) {
        uuidByCall[call] = uuid
        callByUUID[uuid] = call
    }
}
