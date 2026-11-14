#if os(iOS)
    import AVFoundation
    import Foundation
    import LiveCommunicationKit
    import BaresipKit
    import BaresipKitSystemCall

    @available(iOS 17.4, *)
    extension BaresipLiveCommunicationAdapter {
        /// Does nothing; the adapter is ready once it is created.
        ///
        /// - Parameter manager: The conversation manager.
        func conversationManagerDidBegin(_ manager: ConversationManager) {}

        /// Hangs up every call after the system reset the conversation manager.
        ///
        /// - Parameter manager: The conversation manager.
        func conversationManagerDidReset(_ manager: ConversationManager) {
            let (calls, waiters) = lock.withLock {
                () -> ([BaresipCallID], [CheckedContinuation<BaresipCallID, Error>]) in
                let calls = book.reset()
                let waiters = Array(placedCallWaiters.values)
                placedCallWaiters.removeAll()
                return (calls, waiters)
            }
            for waiter in waiters {
                waiter.resume(throwing: BaresipLiveCommunicationError.managerReset)
            }
            let pendingActions = lock.withLock { () -> [CheckedContinuation<Void, Error>] in
                defer { self.actionWaiters.removeAll() }
                return Array(self.actionWaiters.values)
            }
            for waiter in pendingActions {
                waiter.resume(throwing: BaresipLiveCommunicationError.managerReset)
            }
            Task {
                for call in calls {
                    try? await engine.hangUp(callID: call)
                }
                await audioSessionChanged(active: false)
            }
        }

        /// Does nothing; the engine's events drive the calls.
        ///
        /// - Parameters:
        ///   - manager: The conversation manager.
        ///   - conversation: The conversation that changed.
        func conversationManager(_ manager: ConversationManager,
                                 conversationChanged conversation: Conversation) {}

        /// Tells the audio session handler, or else the engine, that the system activated the session.
        ///
        /// - Parameters:
        ///   - manager: The conversation manager.
        ///   - audioSession: The activated session.
        func conversationManager(_ manager: ConversationManager, didActivate audioSession: AVAudioSession) {
            Task {
                await audioSessionChanged(active: true)
            }
        }

        /// Tells the audio session handler, or else the engine, that the system deactivated the session.
        ///
        /// - Parameters:
        ///   - manager: The conversation manager.
        ///   - audioSession: The deactivated session.
        func conversationManager(_ manager: ConversationManager, didDeactivate audioSession: AVAudioSession) {
            Task {
                await audioSessionChanged(active: false)
            }
        }

        /// Carries out an action of the user or the app on the engine: start, join, end, pause,
        /// mute and keypad tones. Other actions, such as merging calls, fail with
        /// ``BaresipLiveCommunicationError/unsupportedAction``.
        ///
        /// - Parameters:
        ///   - manager: The conversation manager.
        ///   - action: The action.
        func conversationManager(_ manager: ConversationManager, perform action: ConversationAction) {
            switch action {
            case let start as StartConversationAction:
                performStart(start)
            case let join as JoinConversationAction:
                performJoin(join)
            case let end as EndConversationAction:
                performEnd(end)
            case let pause as PauseConversationAction:
                performPause(pause)
            case let mute as MuteConversationAction:
                performMute(mute)
            case let tone as PlayToneAction:
                performTone(tone)
            default:
                complete(action, error: BaresipLiveCommunicationError.unsupportedAction)
            }
        }

        /// Gives up on an action that the adapter did not finish before the system's time limit.
        ///
        /// Whoever waits for the action gets ``BaresipLiveCommunicationError/actionTimedOut``. The
        /// system fails a call whose start or join timed out, so the engine's side of it is ended
        /// as well: an outgoing call is hung up as soon as the engine has placed it, an incoming
        /// one at once.
        ///
        /// - Parameters:
        ///   - manager: The conversation manager.
        ///   - action: The action that timed out.
        func conversationManager(_ manager: ConversationManager, timedOutPerforming action: ConversationAction) {
            takeActionWaiter(action.uuid)?.resume(throwing: BaresipLiveCommunicationError.actionTimedOut)
            let uuid = action.conversationUUID
            if action is StartConversationAction {
                let placed = lock.withLock { book.startTimedOut(uuid) }
                takePlacedCallWaiter(uuid)?.resume(throwing: BaresipLiveCommunicationError.actionTimedOut)
                if let placed {
                    Task {
                        try? await engine.hangUp(callID: placed)
                    }
                }
            } else if action is JoinConversationAction, let call = callID(for: uuid) {
                Task {
                    try? await engine.hangUp(callID: call)
                }
            }
        }

        private func performStart(_ action: StartConversationAction) {
            let box = UncheckedSendable(value: action)
            let video = action.isVideo
            let uuid = action.conversationUUID
            let destination = lock.withLock { book.takeStartDestination(uuid) }
                ?? action.handles.first?.value
            guard let destination, !destination.isEmpty else {
                action.fail()
                takePlacedCallWaiter(uuid)?.resume(throwing: BaresipLiveCommunicationError.unknownCall)
                return
            }
            Task {
                do {
                    let id = try await engine.makeCall(destination: destination, video: video)
                    let bound = lock.withLock { book.placed(id, uuid: uuid) }
                    if !bound {
                        try? await engine.hangUp(callID: id)
                        return
                    }
                    box.value.fulfill(dateStarted: Date())
                    takePlacedCallWaiter(uuid)?.resume(returning: id)
                    await reconcileOutgoing(id, uuid: uuid)
                } catch {
                    lock.withLock { book.startFailed(uuid) }
                    box.value.fail()
                    takePlacedCallWaiter(uuid)?.resume(throwing: error)
                }
            }
        }

        /// Answers the call, or remembers the answer until the INVITE of a push call arrives.
        private func performJoin(_ action: JoinConversationAction) {
            let uuid = action.conversationUUID
            let box = UncheckedSendable(value: action)
            let target = lock.withLock { book.answerTarget(uuid) }
            guard case .call(let call) = target else {
                complete(action, error: target == .awaitsInvite ? nil : BaresipLiveCommunicationError.unknownCall) {
                    box.value.fulfill(dateConnected: Date())
                }
                return
            }
            let camera = lock.withLock { book.takeAnswerCamera(uuid) }
            Task {
                do {
                    let hasVideo = await (try? engine.callInfo(callID: call))?.hasVideo ?? false
                    let video = camera.sendsCamera(otherwise: hasVideo && sendsCameraOnAnswer)
                    try await engine.answer(callID: call, video: video)
                    complete(box.value, error: nil) {
                        box.value.fulfill(dateConnected: Date())
                    }
                } catch {
                    complete(box.value, error: error)
                }
            }
        }

        /// Hangs up the call, or remembers that a push call was declined until its INVITE arrives.
        private func performEnd(_ action: EndConversationAction) {
            let uuid = action.conversationUUID
            let box = UncheckedSendable(value: action)
            let deadline = ContinuousClock.now.advanced(by: pushInviteTimeout)
            let call = lock.withLock { book.end(uuid, declineUntil: deadline) }
            guard let call else {
                complete(action, error: nil) {
                    box.value.fulfill(dateEnded: Date())
                }
                return
            }
            Task {
                try? await engine.hangUp(callID: call)
                complete(box.value, error: nil) {
                    box.value.fulfill(dateEnded: Date())
                }
            }
        }

        private func performPause(_ action: PauseConversationAction) {
            guard let call = callID(for: action.conversationUUID) else {
                complete(action, error: BaresipLiveCommunicationError.unknownCall)
                return
            }
            let hold = action.isPaused
            perform(action) { engine in
                if hold {
                    try await engine.hold(callID: call)
                } else {
                    try await engine.resume(callID: call)
                }
            }
        }

        private func performMute(_ action: MuteConversationAction) {
            guard let call = callID(for: action.conversationUUID) else {
                complete(action, error: BaresipLiveCommunicationError.unknownCall)
                return
            }
            let muted = action.isMuted
            let observers = lock.withLock { muteObservers }
            perform(action) { engine in
                try await engine.setMicrophoneMuted(muted, callID: call)
                for observer in observers {
                    observer(call, muted)
                }
            }
        }

        private func performTone(_ action: PlayToneAction) {
            guard let call = callID(for: action.conversationUUID) else {
                complete(action, error: BaresipLiveCommunicationError.unknownCall)
                return
            }
            let digits = action.digits
            perform(action) { engine in
                try await engine.sendDTMF(callID: call, digits: digits)
            }
        }

        private func perform(_ action: ConversationAction,
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
