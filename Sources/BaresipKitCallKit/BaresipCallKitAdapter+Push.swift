#if os(iOS)
    import CallKit
    import Foundation
    import BaresipKit
    import BaresipKitSystemCall

    extension BaresipCallKitAdapter {
        /// Reports a call announced by a VoIP push to CallKit before its INVITE arrives, without
        /// suspending.
        ///
        /// Call this from the PushKit handler: iOS requires that a call is reported for every VoIP
        /// push before the PushKit delegate method returns, and this method has handed the call to
        /// CallKit when it returns.
        ///
        /// The INVITE that follows is bound to the oldest pushed call it matches. A push that
        /// names a caller matches only an INVITE from the same user and, when `remoteURI` has a
        /// host, the same host; a match on user and host wins over a match on the user alone. A
        /// push without a caller matches the next INVITE unless
        /// ``BaresipCallKitConfiguration/matchesPushWithoutCaller`` is `false`.
        ///
        /// Once the INVITE is bound, CallKit is updated with the INVITE's own caller. If the user
        /// answered first, the call is answered as soon as it arrives; the camera is sent only
        /// when `hasVideo` was `true`. If no INVITE arrives within
        /// ``BaresipCallKitConfiguration/pushInviteTimeout``, the call is ended.
        ///
        /// When CallKit refuses the call, for example during Do Not Disturb, the pushed call is
        /// forgotten: a later INVITE is reported as a call of its own.
        ///
        /// When the user declines the pushed call before its INVITE arrives, the INVITE is
        /// rejected with 486 Busy Here if it arrives within the push timeout. When the INVITE
        /// arrived first and still rings, the push announces a call CallKit already shows: iOS
        /// still requires a report for the push, so `uuid` is reported and ended at once as
        /// answered elsewhere, and the ringing call keeps its own UUID from ``uuid(for:)``.
        ///
        /// With ``BaresipCallKitConfiguration/callUUIDHeader`` an INVITE that carries a UUID is
        /// bound by it instead: only the INVITE with `uuid` in the header takes a pushed call
        /// that named its UUID, and a ringing call with another UUID is no duplicate of it,
        /// whoever its caller is. A push without a UUID (`uuid` is `nil`) is matched by its
        /// caller, also with an INVITE that carries a UUID. A push with the UUID of a call that
        /// waits, rings or runs already is a repeat, reported under a UUID of its own and ended
        /// at once.
        ///
        /// - Parameters:
        ///   - pushedUUID: The call's UUID from the push payload, or `nil` when the payload has none;
        ///     the adapter then makes one.
        ///   - remoteURI: The caller's SIP URI from the push payload, if known.
        ///   - displayName: The caller's name to show.
        ///   - hasVideo: Whether the call is a video call.
        ///   - completion: Called on an arbitrary thread with `nil` once CallKit accepted the call,
        ///     or with the CallKit error when the system refused it.
        public func reportIncomingCallFromPush(uuid pushedUUID: UUID?, remoteURI: String?, displayName: String?,
                                               hasVideo: Bool,
                                               completion: @escaping @Sendable (Error?) -> Void) {
            let update = CXCallUpdate()
            update.remoteHandle = handle(for: remoteURI ?? "unknown")
            update.localizedCallerName = displayName
            update.hasVideo = hasVideo
            let uuid = pushedUUID ?? UUID()
            let announcement = PushCallLedger.Announcement(uuid: uuid, remoteURI: remoteURI, hasVideo: hasVideo,
                                                           namedByServer: pushedUUID != nil)
            let (isDuplicate, reported) = lock.withLock { () -> (Bool, UUID) in
                if callByUUID[uuid] != nil || pushCalls.knows(uuid) {
                    return (true, UUID())
                }
                if pushCalls.duplicatesRingingCall(remoteURI: remoteURI, namedByServer: pushedUUID != nil) {
                    return (true, uuid)
                }
                pushCalls.add(announcement, now: ContinuousClock.now)
                return (false, uuid)
            }
            if !isDuplicate {
                schedulePushExpiry(uuid)
            }
            provider.reportNewIncomingCall(with: reported, update: update) { [weak self] error in
                self?.pushCallReported(reported, isDuplicate: isDuplicate, failed: error != nil)
                completion(error)
            }
        }

        /// Reports a call announced by a VoIP push to CallKit before its INVITE arrives.
        ///
        /// This is ``reportIncomingCallFromPush(uuid:remoteURI:displayName:hasVideo:completion:)``
        /// for `async` code; it returns once CallKit accepted or refused the call. Inside a
        /// PushKit delegate method use the variant with a completion handler instead, because a
        /// task started there runs only after the delegate method has returned.
        ///
        /// - Parameters:
        ///   - uuid: The call's UUID from the push payload, or `nil` when the payload has none;
        ///     the adapter then makes one.
        ///   - remoteURI: The caller's SIP URI from the push payload, if known.
        ///   - displayName: The caller's name to show.
        ///   - hasVideo: Whether the call is a video call.
        /// - Throws: The CallKit error when the system refuses the call, for example during Do Not Disturb.
        public func reportIncomingCallFromPush(uuid: UUID?, remoteURI: String?, displayName: String?,
                                               hasVideo: Bool) async throws {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                reportIncomingCallFromPush(uuid: uuid, remoteURI: remoteURI, displayName: displayName,
                                           hasVideo: hasVideo) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }

        func expirePushCall(_ uuid: UUID) {
            let expired = lock.withLock { () -> Bool in
                guard pushCalls.discard(uuid) else { return false }
                pendingAnswers.remove(uuid)
                return true
            }
            if expired {
                provider.reportCall(with: uuid, endedAt: Date(), reason: .failed)
            }
        }

        private func schedulePushExpiry(_ uuid: UUID) {
            let timeout = pushInviteTimeout
            Task { [weak self] in
                try? await Task.sleep(for: timeout)
                self?.expirePushCall(uuid)
            }
        }

        private func pushCallReported(_ uuid: UUID, isDuplicate: Bool, failed: Bool) {
            if failed {
                if !isDuplicate {
                    forgetRefusedPushCall(uuid)
                }
            } else if isDuplicate {
                provider.reportCall(with: uuid, endedAt: Date(), reason: .answeredElsewhere)
            }
        }

        private func forgetRefusedPushCall(_ uuid: UUID) {
            let orphan = lock.withLock { () -> BaresipCallID? in
                pushCalls.discard(uuid)
                pendingAnswers.remove(uuid)
                return callByUUID[uuid]
            }
            guard let orphan else { return }
            Task {
                try? await engine.reject(callID: orphan, statusCode: Self.busyStatusCode)
            }
        }
    }
#endif
