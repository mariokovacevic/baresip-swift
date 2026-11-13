#if os(iOS)
    import AVFoundation
    import CallKit
    import Foundation
    import BaresipKit
    import BaresipKitSystemCall

    extension BaresipCallKitAdapter: CXProviderDelegate {
        /// Hangs up every call after CallKit reset the provider.
        ///
        /// - Parameter provider: The provider.
        public func providerDidReset(_ provider: CXProvider) {
            let (calls, waiters) = lock.withLock {
                () -> ([BaresipCallID], [CheckedContinuation<BaresipCallID, Error>]) in
                let calls = Array(uuidByCall.keys)
                let waiters = Array(placedCallWaiters.values)
                uuidByCall.removeAll()
                callByUUID.removeAll()
                pendingAnswers.removeAll()
                outgoing.removeAll()
                pushCalls.removeAll()
                placedCallWaiters.removeAll()
                answerVideo.removeAll()
                abandonedStarts.removeAll()
                startDestinations.removeAll()
                return (calls, waiters)
            }
            for waiter in waiters {
                waiter.resume(throwing: CancellationError())
            }
            let pendingActions = lock.withLock { () -> [CheckedContinuation<Void, Error>] in
                defer { self.actionWaiters.removeAll() }
                return Array(self.actionWaiters.values)
            }
            for waiter in pendingActions {
                waiter.resume(throwing: CancellationError())
            }
            Task {
                for call in calls {
                    try? await engine.hangup(callID: call)
                }
                await engine.audioSessionDidDeactivate()
            }
        }

        /// Places the call the user or the app started.
        ///
        /// - Parameters:
        ///   - provider: The provider.
        ///   - action: The start action.
        public func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
            let box = UncheckedSendable(value: action)
            let video = action.isVideo
            let uuid = action.callUUID
            let destination = lock.withLock { startDestinations.removeValue(forKey: uuid) } ?? action.handle.value
            Task {
                do {
                    let id = try await engine.makeCall(destination: destination, video: video)
                    let abandoned = lock.withLock { () -> Bool in
                        if abandonedStarts.remove(uuid) != nil {
                            return true
                        }
                        outgoing.insert(uuid)
                        uuidByCall[id] = uuid
                        callByUUID[uuid] = id
                        return false
                    }
                    if abandoned {
                        try? await engine.hangup(callID: id)
                        return
                    }
                    box.value.fulfill()
                    takePlacedCallWaiter(uuid)?.resume(returning: id)
                    await reconcileOutgoing(id, uuid: uuid)
                } catch {
                    lock.withLock { _ = abandonedStarts.remove(uuid) }
                    box.value.fail()
                    takePlacedCallWaiter(uuid)?.resume(throwing: error)
                }
            }
        }

        /// Gives up on an action that the adapter did not finish before CallKit's time limit.
        ///
        /// Whoever waits for the action gets ``BaresipCallKitError/actionTimedOut``. CallKit fails
        /// a call whose start or answer timed out, so the engine's side of it is ended as well:
        /// an outgoing call is hung up as soon as the engine has placed it, an incoming one at
        /// once.
        ///
        /// - Parameters:
        ///   - provider: The provider.
        ///   - action: The action that timed out.
        public func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
            takeActionWaiter(action.uuid)?.resume(throwing: BaresipCallKitError.actionTimedOut)
            if let start = action as? CXStartCallAction {
                let uuid = start.callUUID
                let placed = lock.withLock { () -> BaresipCallID? in
                    startDestinations[uuid] = nil
                    guard let call = callByUUID[uuid] else {
                        abandonedStarts.insert(uuid)
                        return nil
                    }
                    return call
                }
                takePlacedCallWaiter(uuid)?.resume(throwing: BaresipCallKitError.actionTimedOut)
                if let placed {
                    Task {
                        try? await engine.hangup(callID: placed)
                    }
                }
            } else if let answer = action as? CXAnswerCallAction, let call = callID(for: answer.callUUID) {
                Task {
                    try? await engine.hangup(callID: call)
                }
            }
        }

        /// Answers the call, or remembers the answer until the INVITE of a push call arrives.
        ///
        /// The action fails for a call the adapter does not know.
        ///
        /// - Parameters:
        ///   - provider: The provider.
        ///   - action: The answer action.
        public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
            let uuid = action.callUUID
            let (call, awaitsInvite) = lock.withLock { () -> (BaresipCallID?, Bool) in
                if let call = callByUUID[uuid] {
                    return (call, false)
                }
                guard pushCalls.isAnnounced(uuid) else { return (nil, false) }
                pendingAnswers.insert(uuid)
                return (nil, true)
            }
            guard let call else {
                complete(action, error: awaitsInvite ? nil : CXErrorCodeRequestTransactionError(.unknownCallUUID))
                return
            }
            let box = UncheckedSendable(value: action)
            let requestedVideo = lock.withLock { answerVideo.removeValue(forKey: uuid) }
            Task {
                do {
                    let hasVideo = await (try? engine.callInfo(callID: call))?.hasVideo ?? false
                    let video = requestedVideo ?? (hasVideo && sendsCameraOnAnswer)
                    try await engine.answer(callID: call, video: video)
                    complete(box.value, error: nil)
                } catch {
                    complete(box.value, error: error)
                }
            }
        }

        /// Hangs up the call, or remembers that a push call was declined until its INVITE arrives.
        ///
        /// - Parameters:
        ///   - provider: The provider.
        ///   - action: The end action.
        public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
            let uuid = action.callUUID
            let deadline = ContinuousClock.now.advanced(by: pushInviteTimeout)
            let call = lock.withLock { () -> BaresipCallID? in
                pendingAnswers.remove(uuid)
                pushCalls.decline(uuid, until: deadline)
                return callByUUID[uuid]
            }
            guard let call else {
                complete(action, error: nil)
                return
            }
            let box = UncheckedSendable(value: action)
            Task {
                try? await engine.hangup(callID: call)
                complete(box.value, error: nil)
            }
        }

        /// Holds or resumes the call.
        ///
        /// - Parameters:
        ///   - provider: The provider.
        ///   - action: The hold action.
        public func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
            guard let call = callID(for: action.callUUID) else {
                complete(action, error: CXErrorCodeRequestTransactionError(.unknownCallUUID))
                return
            }
            let hold = action.isOnHold
            perform(action) { engine in
                if hold {
                    try await engine.hold(callID: call)
                } else {
                    try await engine.resume(callID: call)
                }
            }
        }

        /// Mutes or unmutes the microphone.
        ///
        /// - Parameters:
        ///   - provider: The provider.
        ///   - action: The mute action.
        public func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
            guard let call = callID(for: action.callUUID) else {
                complete(action, error: CXErrorCodeRequestTransactionError(.unknownCallUUID))
                return
            }
            let muted = action.isMuted
            let (handler, observers) = lock.withLock { (muteHandler, muteObservers) }
            perform(action) { engine in
                try await engine.setMicrophoneMuted(muted, callID: call)
                handler?(call, muted)
                for observer in observers {
                    observer(call, muted)
                }
            }
        }

        /// Sends the DTMF digits.
        ///
        /// - Parameters:
        ///   - provider: The provider.
        ///   - action: The DTMF action.
        public func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) {
            guard let call = callID(for: action.callUUID) else {
                complete(action, error: CXErrorCodeRequestTransactionError(.unknownCallUUID))
                return
            }
            let digits = action.digits
            perform(action) { engine in
                try await engine.sendDTMF(callID: call, digits: digits)
            }
        }

        /// Tells the engine that CallKit activated the audio session.
        ///
        /// - Parameters:
        ///   - provider: The provider.
        ///   - audioSession: The activated session.
        public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
            Task {
                await engine.audioSessionDidActivate()
            }
        }

        /// Tells the engine that CallKit deactivated the audio session.
        ///
        /// - Parameters:
        ///   - provider: The provider.
        ///   - audioSession: The deactivated session.
        public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
            Task {
                await engine.audioSessionDidDeactivate()
            }
        }

        private func perform(_ action: CXCallAction,
                             _ operation: @escaping @Sendable (BaresipEngine) async throws -> Void) {
            let box = UncheckedSendable(value: action)
            Task {
                do {
                    try await operation(engine)
                    complete(box.value, error: nil)
                } catch {
                    complete(box.value, error: error)
                }
            }
        }
    }
#endif
