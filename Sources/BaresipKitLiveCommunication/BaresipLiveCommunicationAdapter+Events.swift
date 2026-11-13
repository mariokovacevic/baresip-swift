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
            let inviteUUID = await announcedUUID(of: info.id)
            let resolution = lock.withLock { () -> PushCallLedger.Resolution in
                let resolution = pushCalls.resolve(invite: info.remoteURI, uuid: inviteUUID,
                                                   now: ContinuousClock.now)
                if case .announced(let announcement, _) = resolution {
                    uuidByCall[info.id] = announcement.uuid
                    callByUUID[announcement.uuid] = info.id
                    pushCalls.startedRinging(info.id, remoteURI: info.remoteURI, uuid: inviteUUID)
                }
                return resolution
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

        /// The UUID in the INVITE's header named by
        /// ``BaresipLiveCommunicationConfiguration/callUUIDHeader``.
        private func announcedUUID(of call: BaresipCallID) async -> UUID? {
            guard let callUUIDHeader, let value = try? await engine.incomingHeader(callUUIDHeader, callID: call)
            else { return nil }
            return UUID(uuidString: value.trimmingCharacters(in: .whitespaces))
        }

        private func adoptPushedCall(_ announcement: PushCallLedger.Announcement, for info: BaresipCallInfo,
                                     callerConfirmed: Bool) async {
            let uuid = announcement.uuid
            report(.conversationUpdated(conversationUpdate(for: info, replacingAnnouncedName: !callerConfirmed)),
                   for: uuid)
            let answerNow = lock.withLock { pendingAnswers.remove(uuid) != nil }
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
            let uuid = lock.withLock { () -> UUID in
                let uuid = announcedUUID.flatMap { callByUUID[$0] == nil ? $0 : nil } ?? UUID()
                uuidByCall[info.id] = uuid
                callByUUID[uuid] = info.id
                pushCalls.startedRinging(info.id, remoteURI: info.remoteURI, uuid: announcedUUID)
                return uuid
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
