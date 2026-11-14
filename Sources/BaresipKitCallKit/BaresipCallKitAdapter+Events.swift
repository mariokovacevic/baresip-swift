#if os(iOS)
    import CallKit
    import Foundation
    import BaresipKit
    import BaresipKitSystemCall

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
            let inviteUUID = await engine.announcedCallUUID(header: callUUIDHeader, callID: info.id)
            let resolution = lock.withLock {
                book.resolveIncoming(info.id, remoteURI: info.remoteURI, announcedUUID: inviteUUID,
                                     now: ContinuousClock.now)
            }
            switch resolution {
            case .announced(let announcement, let callerConfirmed):
                await adoptPushedCall(announcement, for: info, callerConfirmed: callerConfirmed)
            case .declined:
                try? await engine.reject(callID: info.id, statusCode: Self.busyStatusCode)
            case .unannounced:
                await reportIncoming(info, announcedUUID: inviteUUID)
            }
        }

        private func adoptPushedCall(_ announcement: PushCallLedger.Announcement, for info: BaresipCallInfo,
                                     callerConfirmed: Bool) async {
            let uuid = announcement.uuid
            let update = callUpdate(for: info, replacingAnnouncedName: !callerConfirmed)
            provider.reportCall(with: uuid, updated: update)
            let answerNow = lock.withLock { book.takePendingAnswer(uuid) }
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

        /// Reports an INVITE no push announced. It keeps the UUID its header carries, so a push
        /// that arrives later with the same UUID is recognized.
        private func reportIncoming(_ info: BaresipCallInfo, announcedUUID: UUID?) async {
            let uuid = lock.withLock {
                book.bindUnannounced(info.id, remoteURI: info.remoteURI, announcedUUID: announcedUUID)
            }
            let update = callUpdate(for: info, replacingAnnouncedName: false)
            do {
                try await provider.reportNewIncomingCall(with: uuid, update: update)
            } catch {
                try? await engine.reject(callID: info.id, statusCode: Self.busyStatusCode)
            }
        }

        func callUpdate(for info: BaresipCallInfo, replacingAnnouncedName: Bool) -> CXCallUpdate {
            let update = CXCallUpdate()
            update.remoteHandle = handle(for: info.remoteURI)
            update.localizedCallerName = PushCallLedger.callerName(inviteURI: info.remoteURI,
                                                                   inviteDisplayName: info.remoteDisplayName,
                                                                   replacingAnnouncedName: replacingAnnouncedName)
            update.hasVideo = info.hasVideo
            return update
        }

        private func handleState(_ state: BaresipCallState, of call: BaresipCallID, error: BaresipError?) {
            guard let change = lock.withLock({ book.stateChanged(call, to: state) }) else { return }
            let uuid = change.uuid
            let isOutgoing = change.isOutgoing
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
            switch error.endReason {
            case .answeredElsewhere: return .answeredElsewhere
            case .declinedElsewhere: return .declinedElsewhere
            case nil: break
            }
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
