#if os(iOS)
    import Foundation
    import LiveCommunicationKit
    import BaresipKit

    @available(iOS 17.4, *)
    extension BaresipLiveCommunicationAdapter: BaresipCallController {
        /// Whether the system shows the call, so its actions go through LiveCommunicationKit.
        ///
        /// - Parameter call: The engine call.
        /// - Returns: `true` when the call has a conversation UUID.
        public func controls(_ call: BaresipCallID) -> Bool {
            uuid(for: call) != nil
        }

        /// Places a call through LiveCommunicationKit and returns the engine call once it is placed.
        ///
        /// - Parameters:
        ///   - destination: A SIP URI, user name or number.
        ///   - video: Whether to send the camera.
        /// - Returns: The engine call.
        /// - Throws: The LiveCommunicationKit error when the system refuses the call, or
        ///   `BaresipError` when the engine cannot place it.
        public func placeCall(to destination: String, video: Bool) async throws -> BaresipCallID {
            let uuid = UUID()
            return try await withCheckedThrowingContinuation { continuation in
                lock.withLock { placedCallWaiters[uuid] = continuation }
                Task {
                    do {
                        try await requestOutgoingCall(uuid: uuid, to: destination, displayName: nil, video: video)
                    } catch {
                        takePlacedCallWaiter(uuid)?.resume(throwing: error)
                    }
                }
            }
        }

        /// Answers a call through LiveCommunicationKit, sending the camera as requested instead of
        /// as ``BaresipLiveCommunicationConfiguration/sendsCameraOnAnswer`` says.
        ///
        /// - Parameters:
        ///   - call: The ringing call.
        ///   - video: Whether to send the camera.
        /// - Throws: ``BaresipLiveCommunicationError/unknownCall`` for a call the system does not
        ///   show, or the LiveCommunicationKit error when the system refuses the request.
        public func answer(_ call: BaresipCallID, video: Bool) async throws {
            let uuid = try knownUUID(for: call)
            lock.withLock { book.requestAnswer(uuid, sendsCamera: video) }
            do {
                try await answerCall(uuid: uuid)
            } catch {
                lock.withLock { book.cancelAnswerRequest(uuid) }
                throw error
            }
        }

        /// Ends or declines a call through LiveCommunicationKit.
        ///
        /// - Parameter call: The call.
        /// - Throws: ``BaresipLiveCommunicationError/unknownCall`` for a call the system does not
        ///   show, or the LiveCommunicationKit error when the system refuses the request.
        public func end(_ call: BaresipCallID) async throws {
            try await endCall(uuid: knownUUID(for: call))
        }

        /// Holds or resumes a call through LiveCommunicationKit.
        ///
        /// - Parameters:
        ///   - onHold: `true` to hold.
        ///   - call: The call.
        /// - Throws: ``BaresipLiveCommunicationError/unknownCall`` for a call the system does not
        ///   show, or the LiveCommunicationKit error when the system refuses the request.
        public func setOnHold(_ onHold: Bool, call: BaresipCallID) async throws {
            try await setOnHold(onHold, uuid: knownUUID(for: call))
        }

        /// Mutes or unmutes a call through LiveCommunicationKit.
        ///
        /// - Parameters:
        ///   - muted: `true` to mute.
        ///   - call: The call.
        /// - Throws: ``BaresipLiveCommunicationError/unknownCall`` for a call the system does not
        ///   show, or the LiveCommunicationKit error when the system refuses the request.
        public func setMuted(_ muted: Bool, call: BaresipCallID) async throws {
            try await setMuted(muted, uuid: knownUUID(for: call))
        }

        /// Adds an observer called after a call was muted or unmuted through LiveCommunicationKit,
        /// from the system call screen or the app. It runs on an arbitrary thread.
        ///
        /// - Parameter observer: Called with the call and whether it is muted now.
        public func addMuteObserver(_ observer: @escaping @Sendable (BaresipCallID, Bool) -> Void) {
            lock.withLock { muteObservers.append(observer) }
        }

        func takePlacedCallWaiter(_ uuid: UUID) -> CheckedContinuation<BaresipCallID, Error>? {
            lock.withLock { placedCallWaiters.removeValue(forKey: uuid) }
        }

        private func knownUUID(for call: BaresipCallID) throws -> UUID {
            guard let uuid = uuid(for: call) else {
                throw BaresipLiveCommunicationError.unknownCall
            }
            return uuid
        }
    }
#endif
