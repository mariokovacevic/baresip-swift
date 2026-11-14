#if os(iOS)
    import Foundation
    import LiveCommunicationKit
    import BaresipKit
    import BaresipKitSystemCall

    /// Connects a `BaresipEngine` to LiveCommunicationKit, the successor of CallKit.
    ///
    /// The adapter reports incoming calls to the system call screen as conversations, starts
    /// outgoing calls through the conversation manager, and carries out the user's actions (join,
    /// end, pause, mute, keypad tones) on the engine. It works like `BaresipCallKitAdapter`:
    /// calls announced by a VoIP push are matched to the INVITE that follows by the caller's SIP
    /// URI, or by a UUID header. The `From` header of an INVITE is not authenticated, so the match
    /// shows who the INVITE claims to be from, not who sent it.
    ///
    /// Use one adapter per app, either this one or `BaresipCallKitAdapter`, and report every VoIP
    /// push to the same one.
    ///
    /// ```swift
    /// let calls = BaresipLiveCommunicationAdapter(engine: engine,
    ///                                             configuration: BaresipLiveCommunicationConfiguration())
    /// let uuid = try await calls.startOutgoingCall(to: "sip:bob@example.com")
    /// ```
    @available(iOS 17.4, *)
    public final class BaresipLiveCommunicationAdapter: @unchecked Sendable {
        // SAFETY: `book`, the waiters and the mute observers are read and written only while
        // holding `lock`; the conversation manager is used as LiveCommunicationKit allows from
        // any thread.

        let engine: BaresipEngine
        let manager: ConversationManager
        let managerDelegate = ConversationManagerForwarder()
        let pushInviteTimeout: Duration
        let sendsCameraOnAnswer: Bool
        let callUUIDHeader: String?
        let handleStyle: BaresipHandleStyle
        let lock = NSLock()
        static let systemActionDeadline: Duration = .seconds(60)
        var book: SystemCallBook
        var muteObservers: [@Sendable (BaresipCallID, Bool) -> Void] = []
        var audioSessionHandler: AudioSessionHandler?
        /// Callers of `placeCall(to:video:)` waiting for the engine call of their start action.
        var placedCallWaiters: [UUID: CheckedContinuation<BaresipCallID, Error>] = [:]
        /// Callers waiting until the adapter carried out their action, by action UUID.
        var actionWaiters: [UUID: CheckedContinuation<Void, Error>] = [:]
        private var eventTask: Task<Void, Never>?

        /// Creates the adapter and its conversation manager, and starts following engine events.
        ///
        /// The adapter is subscribed to the engine's events when the initializer returns, so a
        /// call that arrives right afterwards is not missed.
        ///
        /// - Parameters:
        ///   - engine: The engine whose calls are shown by the system.
        ///   - configuration: LiveCommunicationKit settings.
        public init(engine: BaresipEngine, configuration: BaresipLiveCommunicationConfiguration) {
            self.engine = engine
            pushInviteTimeout = configuration.pushInviteTimeout
            sendsCameraOnAnswer = configuration.sendsCameraOnAnswer
            callUUIDHeader = configuration.callUUIDHeader
            handleStyle = configuration.handleStyle
            book = SystemCallBook(matchesPushWithoutCaller: configuration.matchesPushWithoutCaller)
            let managerConfiguration = ConversationManager.Configuration(
                ringtoneName: configuration.ringtoneName,
                iconTemplateImageData: configuration.iconTemplateImageData,
                maximumConversationGroups: configuration.maximumConversationGroups,
                maximumConversationsPerConversationGroup: configuration.maximumConversationsPerConversationGroup,
                includesConversationInRecents: configuration.includesCallsInRecents,
                supportsVideo: configuration.supportsVideo,
                supportedHandleTypes: [.generic, .phoneNumber]
            )
            manager = ConversationManager(configuration: managerConfiguration)
            let events = engine.events
            managerDelegate.adapter = self
            manager.delegate = managerDelegate
            eventTask = Task { [weak self] in
                for await event in events {
                    await self?.handle(event)
                }
            }
        }

        deinit {
            eventTask?.cancel()
            manager.invalidate()
        }

        /// Called when the system activates (`true`) or deactivates (`false`) the audio session of
        /// the calls.
        public typealias AudioSessionHandler = @Sendable (_ active: Bool) async -> Void

        /// Sends the system's audio session activation to a handler instead of to the engine.
        ///
        /// Use it to tell a `BaresipAudioSessionController` that LiveCommunicationKit owns the session, so the
        /// controller handles interruptions and resets of the media services accordingly:
        ///
        /// ```swift
        /// calls.setAudioSessionHandler { active in
        ///     if active {
        ///         await audio.didActivateFromCallKit()
        ///     } else {
        ///         await audio.didDeactivateFromCallKit()
        ///     }
        /// }
        /// ```
        ///
        /// The handler must tell the engine, as the controller does. Without a handler, the
        /// adapter calls `audioSessionDidActivate()` and `audioSessionDidDeactivate()` on the engine
        /// itself.
        ///
        /// - Parameter handler: The handler, or `nil` to tell the engine directly.
        public func setAudioSessionHandler(_ handler: AudioSessionHandler?) {
            lock.withLock { audioSessionHandler = handler }
        }

        func audioSessionChanged(active: Bool) async {
            let handler = lock.withLock { audioSessionHandler }
            if let handler {
                await handler(active)
            } else if active {
                await engine.audioSessionDidActivate()
            } else {
                await engine.audioSessionDidDeactivate()
            }
        }

        /// The conversation UUID of an engine call, if the system shows the call.
        ///
        /// - Parameter call: The engine call.
        /// - Returns: The UUID used with LiveCommunicationKit, or `nil`.
        public func uuid(for call: BaresipCallID) -> UUID? {
            lock.withLock { book.uuid(for: call) }
        }

        /// Starts an outgoing call through LiveCommunicationKit.
        ///
        /// The system asks the adapter to start the conversation, which then calls
        /// `BaresipEngine.makeCall(accountID:destination:video:audio:)`.
        ///
        /// - Parameters:
        ///   - destination: A SIP URI, user name or number.
        ///   - displayName: The name the system shows for the other side.
        ///   - video: Whether to offer video.
        /// - Returns: The conversation UUID of the call.
        /// - Throws: The LiveCommunicationKit error when the system refuses the call.
        public func startOutgoingCall(to destination: String, displayName: String? = nil,
                                      video: Bool = false) async throws -> UUID {
            let uuid = UUID()
            try await requestOutgoingCall(uuid: uuid, to: destination, displayName: displayName, video: video)
            return uuid
        }

        func requestOutgoingCall(uuid: UUID, to destination: String, displayName: String?,
                                 video: Bool) async throws {
            let action = StartConversationAction(conversationUUID: uuid,
                                                 handles: [handle(for: destination, displayName: displayName)],
                                                 isVideo: video)
            lock.withLock { book.willStart(uuid, destination: destination) }
            do {
                try await manager.perform([action])
            } catch {
                lock.withLock { book.startNotRequested(uuid) }
                throw error
            }
        }

        /// Answers (joins) an incoming call through LiveCommunicationKit.
        ///
        /// Use this when the app's own incoming call screen answers, so the system call screen
        /// stops ringing and the system activates the audio session.
        ///
        /// - Parameter uuid: The conversation UUID of the call, from ``uuid(for:)``.
        /// - Throws: The LiveCommunicationKit error when the system refuses the request, or the
        ///   engine's error when the action fails on the call.
        public func answerCall(uuid: UUID) async throws {
            try await requestAndWait(JoinConversationAction(conversationUUID: uuid))
        }

        /// Mutes or unmutes the microphone through LiveCommunicationKit, so the system call screen
        /// shows the same state as the app.
        ///
        /// - Parameters:
        ///   - muted: `true` to mute.
        ///   - uuid: The conversation UUID of the call.
        /// - Throws: The LiveCommunicationKit error when the system refuses the request, or the
        ///   engine's error when the action fails on the call.
        public func setMuted(_ muted: Bool, uuid: UUID) async throws {
            try await requestAndWait(MuteConversationAction(conversationUUID: uuid, isMuted: muted))
        }

        /// Holds or resumes a call through LiveCommunicationKit, which calls it pausing.
        ///
        /// - Parameters:
        ///   - onHold: `true` to hold.
        ///   - uuid: The conversation UUID of the call.
        /// - Throws: The LiveCommunicationKit error when the system refuses the request, or the
        ///   engine's error when the action fails on the call.
        public func setOnHold(_ onHold: Bool, uuid: UUID) async throws {
            try await requestAndWait(PauseConversationAction(conversationUUID: uuid, isPaused: onHold))
        }

        /// Ends a call through LiveCommunicationKit.
        ///
        /// - Parameter uuid: The conversation UUID of the call.
        /// - Throws: The LiveCommunicationKit error when the system refuses the request, or the
        ///   engine's error when the action fails on the call.
        public func endCall(uuid: UUID) async throws {
            try await requestAndWait(EndConversationAction(conversationUUID: uuid))
        }

        /// Requests an action and returns once the adapter carried it out on the engine, so a
        /// failure on the engine reaches the caller.
        func requestAndWait(_ action: ConversationAction) async throws {
            let id = action.uuid
            let box = UncheckedSendable(value: action)
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                lock.withLock { actionWaiters[id] = continuation }
                Task {
                    do {
                        try await manager.perform([box.value])
                    } catch {
                        takeActionWaiter(id)?.resume(throwing: error)
                    }
                }
                Task { [weak self] in
                    try? await Task.sleep(for: BaresipLiveCommunicationAdapter.systemActionDeadline)
                    self?.takeActionWaiter(id)?.resume(throwing: BaresipLiveCommunicationError.actionTimedOut)
                }
            }
        }

        func takeActionWaiter(_ id: UUID) -> CheckedContinuation<Void, Error>? {
            lock.withLock { actionWaiters.removeValue(forKey: id) }
        }

        /// Fulfills or fails an action and tells a caller waiting in ``requestAndWait(_:)``.
        ///
        /// - Parameters:
        ///   - action: The action.
        ///   - error: The error that failed it, or `nil`.
        ///   - fulfill: Fulfills an action whose class takes a date; `nil` for the others.
        func complete(_ action: ConversationAction, error: Error?, fulfill: (() -> Void)? = nil) {
            if let error {
                action.fail()
                takeActionWaiter(action.uuid)?.resume(throwing: error)
            } else {
                if let fulfill {
                    fulfill()
                } else {
                    action.fulfill()
                }
                takeActionWaiter(action.uuid)?.resume()
            }
        }

        /// The handle of a SIP URI, user name or number, as `BaresipHandleStyle` says.
        func handle(for address: String, displayName: String? = nil) -> Handle {
            if handleStyle == .phoneNumberWhenNumeric, let number = SIPIdentity(address).phoneNumber {
                return Handle(type: .phoneNumber, value: number, displayName: displayName)
            }
            return Handle(type: .generic, value: address, displayName: displayName)
        }

        /// What the system offers on the call screen: keypad tones and hold always, video when
        /// the call has it.
        func capabilities(video: Bool) -> Conversation.Capabilities {
            var capabilities: Conversation.Capabilities = [.playingTones, .pausing]
            if video {
                capabilities.insert(.video)
            }
            return capabilities
        }

        /// Reports an event of a call the system shows; nothing happens for a conversation the
        /// manager does not know.
        func report(_ event: Conversation.Event, for uuid: UUID) {
            guard let conversation = manager.conversations.first(where: { $0.uuid == uuid }) else { return }
            manager.reportConversationEvent(event, for: conversation)
        }

        func unbind(_ call: BaresipCallID) -> UUID? {
            lock.withLock { book.unbind(call) }
        }

        func callID(for uuid: UUID) -> BaresipCallID? {
            lock.withLock { book.call(for: uuid) }
        }
    }
#endif
