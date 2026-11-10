#if os(iOS)
    import CallKit
    import Foundation
    import BaresipKit

    extension BaresipCallKitAdapter {
        static let busyStatusCode = 486
        static let declineStatusCode = 600

        func handle(_ event: BaresipEvent) async {
            switch event {
            case .incomingCall(let info, _):
                await handleIncoming(info)
            case .call(let call, let state, let error):
                handleState(state, of: call, error: error)
            default:
                break
            }
        }

        private func handleIncoming(_ info: BaresipCallInfo) async {
            let resolution = lock.withLock { () -> PushCallLedger.Resolution in
                let resolution = pushCalls.resolve(invite: info.remoteURI, now: ContinuousClock.now)
                if case .announced(let announcement, _) = resolution {
                    uuidByCall[info.id] = announcement.uuid
                    callByUUID[announcement.uuid] = info.id
                    pushCalls.startedRinging(info.id, remoteURI: info.remoteURI)
                }
                return resolution
            }
            switch resolution {
            case .announced(let announcement, let callerConfirmed):
                await adoptPushedCall(announcement, for: info, callerConfirmed: callerConfirmed)
            case .declined:
                try? await engine.reject(callID: info.id, statusCode: Self.busyStatusCode)
            case .unannounced:
                await reportIncoming(info)
            }
        }

        private func adoptPushedCall(_ announcement: PushCallLedger.Announcement, for info: BaresipCallInfo,
                                     callerConfirmed: Bool) async {
            let uuid = announcement.uuid
            let update = Self.callUpdate(for: info, replacingAnnouncedName: !callerConfirmed)
            provider.reportCall(with: uuid, updated: update)
            let answerNow = lock.withLock { pendingAnswers.remove(uuid) != nil }
            guard answerNow else { return }
            let video = PushCallLedger.sendsCamera(pushHadVideo: announcement.hasVideo,
                                                   inviteHasVideo: info.hasVideo,
                                                   sendsCameraOnAnswer: sendsCameraOnAnswer)
            do {
                try await engine.answer(callID: info.id, video: video)
            } catch {
                provider.reportCall(with: uuid, endedAt: Date(), reason: .failed)
                try? await engine.hangup(callID: info.id)
            }
        }

        private func reportIncoming(_ info: BaresipCallInfo) async {
            let uuid = UUID()
            bind(info.id, uuid)
            lock.withLock {
                pushCalls.startedRinging(info.id, remoteURI: info.remoteURI)
            }
            let update = Self.callUpdate(for: info, replacingAnnouncedName: false)
            do {
                try await provider.reportNewIncomingCall(with: uuid, update: update)
            } catch {
                try? await engine.reject(callID: info.id, statusCode: Self.busyStatusCode)
            }
        }

        static func callUpdate(for info: BaresipCallInfo, replacingAnnouncedName: Bool) -> CXCallUpdate {
            let update = CXCallUpdate()
            update.remoteHandle = CXHandle(type: .generic, value: info.remoteURI)
            update.localizedCallerName = PushCallLedger.callerName(inviteURI: info.remoteURI,
                                                                   inviteDisplayName: info.remoteDisplayName,
                                                                   replacingAnnouncedName: replacingAnnouncedName)
            update.hasVideo = info.hasVideo
            return update
        }

        private func handleState(_ state: BaresipCallState, of call: BaresipCallID, error: BaresipError?) {
            guard let uuid = uuid(for: call) else { return }
            let isOutgoing = lock.withLock { () -> Bool in
                if state != .incoming, state != .earlyMedia {
                    pushCalls.stoppedRinging(call)
                }
                return outgoing.contains(uuid)
            }
            switch state {
            case .outgoingRinging, .earlyMedia:
                if isOutgoing {
                    provider.reportOutgoingCall(with: uuid, startedConnectingAt: Date())
                }
            case .connected, .streamsRunning:
                if isOutgoing {
                    provider.reportOutgoingCall(with: uuid, connectedAt: Date())
                }
            case .ended, .failed:
                provider.reportCall(with: uuid, endedAt: Date(), reason: Self.endedReason(for: error))
            case .released:
                _ = unbind(call)
            default:
                break
            }
        }

        static func endedReason(for error: BaresipError?) -> CXCallEndedReason {
            guard let error else { return .remoteEnded }
            if error.sipStatus == busyStatusCode || error.sipStatus == declineStatusCode {
                return .unanswered
            }
            return .failed
        }

        func reconcileOutgoing(_ call: BaresipCallID, uuid: UUID) async {
            do {
                let info = try await engine.callInfo(callID: call)
                switch info.state {
                case .outgoingRinging, .earlyMedia:
                    provider.reportOutgoingCall(with: uuid, startedConnectingAt: Date())
                case .connected, .streamsRunning:
                    provider.reportOutgoingCall(with: uuid, connectedAt: Date())
                case .ended, .failed, .released:
                    provider.reportCall(with: uuid, endedAt: Date(), reason: .failed)
                default:
                    break
                }
            } catch {
                if unbind(call) != nil {
                    provider.reportCall(with: uuid, endedAt: Date(), reason: .failed)
                }
            }
        }
    }
#endif
