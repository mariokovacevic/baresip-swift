#if os(iOS)
    import Foundation
    import LiveCommunicationKit
    import BaresipKit
    import BaresipKitSystemCall

    @available(iOS 17.4, *)
    extension BaresipLiveCommunicationAdapter {
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
            report(.conversationUpdated(conversationUpdate(for: info, replacingAnnouncedName: !callerConfirmed)),
                   for: uuid)
            let answerNow = lock.withLock { book.takePendingAnswer(uuid) }
            guard answerNow else { return }
            let video = PushCallLedger.sendsCamera(pushHadVideo: announcement.hasVideo,
                                                   inviteHasVideo: info.hasVideo,
                                                   sendsCameraOnAnswer: sendsCameraOnAnswer)
            do {
                try await engine.answer(callID: info.id, video: video)
            } catch {
                report(.conversationEnded(Date(), .failed), for: uuid)
                try? await engine.hangup(callID: info.id)
            }
        }

        /// Reports an INVITE no push announced. It keeps the UUID its header carries, so a push
        /// that arrives later with the same UUID is recognized.
        private func reportIncoming(_ info: BaresipCallInfo, announcedUUID: UUID?) async {
            let uuid = lock.withLock {
                book.bindUnannounced(info.id, remoteURI: info.remoteURI, announcedUUID: announcedUUID)
            }
            do {
                try await manager.reportNewIncomingConversation(
                    uuid: uuid, update: conversationUpdate(for: info, replacingAnnouncedName: true)
                )
            } catch {
                try? await engine.reject(callID: info.id, statusCode: Self.busyStatusCode)
            }
        }

        /// The update for a call's INVITE. Without a display name in the INVITE, a push's name is
        /// kept when the INVITE confirmed the push's caller, so only the capabilities change.
        func conversationUpdate(for info: BaresipCallInfo, replacingAnnouncedName: Bool) -> Conversation.Update {
            let capabilities = capabilities(video: info.hasVideo)
            guard let name = PushCallLedger.callerName(inviteURI: info.remoteURI,
                                                       inviteDisplayName: info.remoteDisplayName,
                                                       replacingAnnouncedName: replacingAnnouncedName)
            else {
                return Conversation.Update(capabilities: capabilities)
            }
            let caller = handle(for: info.remoteURI, displayName: name)
            return Conversation.Update(members: [caller], activeRemoteMembers: [caller],
                                       capabilities: capabilities)
        }

        private func handleState(_ state: BaresipCallState, of call: BaresipCallID, error: BaresipError?) {
            guard let change = lock.withLock({ book.stateChanged(call, to: state) }) else { return }
            let uuid = change.uuid
            let isOutgoing = change.isOutgoing
            switch state {
            case .outgoingRinging, .earlyMedia:
                if isOutgoing {
                    report(.conversationStartedConnecting(Date()), for: uuid)
                }
            case .connected, .streamsRunning:
                if isOutgoing {
                    report(.conversationConnected(Date()), for: uuid)
                }
            case .ended, .failed:
                report(.conversationEnded(Date(), Self.endedReason(for: error)), for: uuid)
            case .released:
                _ = unbind(call)
            default:
                break
            }
        }

        static func endedReason(for error: BaresipError?) -> Conversation.EndedReason {
            guard let error else { return .remoteEnded }
            switch error.endReason {
            case .answeredElsewhere: return .joinedElsewhere
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
                    report(.conversationStartedConnecting(Date()), for: uuid)
                case .connected, .streamsRunning:
                    report(.conversationConnected(Date()), for: uuid)
                case .ended, .failed, .released:
                    report(.conversationEnded(Date(), .failed), for: uuid)
                default:
                    break
                }
            } catch {
                if unbind(call) != nil {
                    report(.conversationEnded(Date(), .failed), for: uuid)
                }
            }
        }
    }
#endif
