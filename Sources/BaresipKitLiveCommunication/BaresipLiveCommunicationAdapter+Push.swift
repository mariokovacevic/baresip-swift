#if os(iOS)
    import Foundation
    import LiveCommunicationKit
    import BaresipKit
    import BaresipKitSystemCall

    @available(iOS 17.4, *)
    extension BaresipLiveCommunicationAdapter {
        /// Reports a call announced by a VoIP push to the system before its INVITE arrives.
        ///
        /// iOS requires that a call is reported for every VoIP push before PushKit's completion
        /// handler runs. LiveCommunicationKit reports only asynchronously, so call this from
        /// `BaresipPushKitAdapter`'s asynchronous push handler, which completes the push after the
        /// handler returned. Without a push adapter, await it in PushKit's delegate method before
        /// calling the completion handler.
        ///
        /// The INVITE that follows is bound to the pushed call exactly as with
        /// `BaresipCallKitAdapter.reportIncomingCallFromPush(uuid:remoteURI:displayName:hasVideo:)`:
        /// by the UUID in the header named by
        /// ``BaresipLiveCommunicationConfiguration/callUUIDHeader``, or else by the caller. If the
        /// user answered first, the call is answered as soon as the INVITE arrives; if the user
        /// declined, the INVITE is rejected with 486 Busy Here. If no INVITE arrives within
        /// ``BaresipLiveCommunicationConfiguration/pushInviteTimeout``, the call is ended.
        ///
        /// A push for a call the system already shows is reported under a UUID of its own and
        /// ended at once as joined elsewhere, because iOS still requires a report for it.
        ///
        /// - Parameters:
        ///   - pushedUUID: The call's UUID from the push payload, or `nil` when the payload has none;
        ///     the adapter then makes one.
        ///   - remoteURI: The caller's SIP URI from the push payload, if known.
        ///   - displayName: The caller's name to show.
        ///   - hasVideo: Whether the call is a video call.
        /// - Throws: The LiveCommunicationKit error when the system refuses the call, for example
        ///   during Do Not Disturb.
        public func reportIncomingCallFromPush(uuid pushedUUID: UUID?, remoteURI: String?, displayName: String?,
                                               hasVideo: Bool) async throws {
            let outcome = lock.withLock {
                book.announcePush(uuid: pushedUUID, remoteURI: remoteURI, hasVideo: hasVideo, now: ContinuousClock.now)
            }
            let isDuplicate = outcome.isDuplicate
            let reported = outcome.reported
            if !isDuplicate {
                schedulePushExpiry(reported)
            }
            let caller = handle(for: remoteURI ?? "unknown", displayName: displayName)
            let update = Conversation.Update(members: [caller], activeRemoteMembers: [caller],
                                             capabilities: capabilities(video: hasVideo))
            do {
                try await manager.reportNewIncomingConversation(uuid: reported, update: update)
            } catch {
                if !isDuplicate {
                    forgetRefusedPushCall(reported)
                }
                throw error
            }
            if isDuplicate {
                report(.conversationEnded(Date(), .joinedElsewhere), for: reported)
            }
        }

        func expirePushCall(_ uuid: UUID) {
            let expired = lock.withLock { book.expirePush(uuid) }
            if expired {
                report(.conversationEnded(Date(), .failed), for: uuid)
            }
        }

        private func schedulePushExpiry(_ uuid: UUID) {
            let timeout = pushInviteTimeout
            Task { [weak self] in
                try? await Task.sleep(for: timeout)
                self?.expirePushCall(uuid)
            }
        }

        private func forgetRefusedPushCall(_ uuid: UUID) {
            let orphan = lock.withLock { book.forgetRefusedPush(uuid) }
            guard let orphan else { return }
            Task {
                try? await engine.reject(callID: orphan, statusCode: Self.busyStatusCode)
            }
        }
    }
#endif
