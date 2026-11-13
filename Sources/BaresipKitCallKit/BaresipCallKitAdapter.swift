#if os(iOS)
    import CallKit
    import Foundation
    import BaresipKit
    import BaresipKitSystemCall

    /// Connects a `BaresipEngine` to CallKit.
    ///
    /// The adapter reports incoming calls to the system call screen, starts outgoing calls through
    /// `CXCallController`, and carries out the user's actions (answer, end, hold, mute, DTMF) on
    /// the engine. Calls announced by a VoIP push are matched to the INVITE that follows by the
    /// caller's SIP URI. The `From` header of an INVITE is not authenticated, so the match shows
    /// who the INVITE claims to be from, not who sent it.
    ///
    /// ```swift
    /// let callKit = BaresipCallKitAdapter(engine: engine, configuration: BaresipCallKitConfiguration())
    /// let uuid = try await callKit.startOutgoingCall(to: "sip:bob@example.com")
    /// ```
    public final class BaresipCallKitAdapter: NSObject, @unchecked Sendable {
        // SAFETY: the mutable dictionaries, sets and `pushCalls` are read and written only while
        // holding `lock`; CXProvider and CXCallController are thread-safe.

        let engine: BaresipEngine
        let provider: CXProvider
        let controller = CXCallController()
        let pushInviteTimeout: Duration
        let sendsCameraOnAnswer: Bool
        let callUUIDHeader: String?
        let handleStyle: BaresipHandleStyle
        let lock = NSLock()
        var uuidByCall: [BaresipCallID: UUID] = [:]
        var callByUUID: [UUID: BaresipCallID] = [:]
        var pendingAnswers: Set<UUID> = []
        var outgoing: Set<UUID> = []
        var pushCalls: PushCallLedger
        var muteHandler: (@Sendable (BaresipCallID, Bool) -> Void)?
        var muteObservers: [@Sendable (BaresipCallID, Bool) -> Void] = []
        /// Callers of `placeCall(to:video:)` waiting for the engine call of their start action.
        var placedCallWaiters: [UUID: CheckedContinuation<BaresipCallID, Error>] = [:]
        /// Whether to send the camera, for answers the app requested with `answer(_:video:)`.
        var answerVideo: [UUID: Bool] = [:]
        /// Callers waiting until the provider carried out their action, by action UUID.
        var actionWaiters: [UUID: CheckedContinuation<Void, Error>] = [:]
        /// Outgoing calls whose start action timed out before the engine placed them.
        var abandonedStarts: Set<UUID> = []
        /// What to dial for the outgoing calls the adapter asked CallKit to start; the handle
        /// CallKit gets can be the number alone.
        var startDestinations: [UUID: String] = [:]
        private var eventTask: Task<Void, Never>?

        /// Creates the adapter and its CallKit provider, and starts following engine events.
        ///
        /// The adapter is subscribed to the engine's events when the initializer returns, so a
        /// call that arrives right afterwards is not missed.
        ///
        /// - Parameters:
        ///   - engine: The engine whose calls are shown in CallKit.
        ///   - configuration: CallKit settings.
        public init(engine: BaresipEngine, configuration: BaresipCallKitConfiguration) {
            self.engine = engine
            pushInviteTimeout = configuration.pushInviteTimeout
            sendsCameraOnAnswer = configuration.sendsCameraOnAnswer
            callUUIDHeader = configuration.callUUIDHeader
            handleStyle = configuration.handleStyle
            pushCalls = PushCallLedger(matchesPushWithoutCaller: configuration.matchesPushWithoutCaller)
            let providerConfiguration = CXProviderConfiguration()
            providerConfiguration.supportsVideo = configuration.supportsVideo
            providerConfiguration.maximumCallsPerCallGroup = configuration.maximumCallsPerCallGroup
            providerConfiguration.supportedHandleTypes = [.generic, .phoneNumber]
            providerConfiguration.includesCallsInRecents = configuration.includesCallsInRecents
            providerConfiguration.iconTemplateImageData = configuration.iconTemplateImageData
            providerConfiguration.ringtoneSound = configuration.ringtoneSound
            provider = CXProvider(configuration: providerConfiguration)
            let events = engine.events
            super.init()
            provider.setDelegate(self, queue: nil)
            eventTask = Task { [weak self] in
                for await event in events {
                    await self?.handle(event)
                }
            }
        }

        deinit {
            eventTask?.cancel()
            provider.invalidate()
        }

        /// Changes the ringtone of the calls reported from now on, for example after the user
        /// picked one in the app's settings.
        ///
        /// - Parameter sound: The name of a sound file in the app's main bundle, or `nil` for the
        ///   ringtone chosen in the iOS Settings app. CallKit ignores a file it cannot find there.
        public func setRingtoneSound(_ sound: String?) {
            let configuration = provider.configuration
            configuration.ringtoneSound = sound
            provider.configuration = configuration
        }

        /// The CallKit UUID of an engine call, if the call is known to CallKit.
        ///
        /// - Parameter call: The engine call.
        /// - Returns: The UUID used with CallKit, or `nil`.
        public func uuid(for call: BaresipCallID) -> UUID? {
            lock.withLock { uuidByCall[call] }
        }

        /// Starts an outgoing call through CallKit.
        ///
        /// CallKit asks the adapter to perform the call, which then calls
        /// `BaresipEngine.makeCall(accountID:destination:video:audio:)`.
        ///
        /// - Parameters:
        ///   - destination: A SIP URI, user name or number.
        ///   - displayName: A contact identifier shown by the system.
        ///   - video: Whether to offer video.
        /// - Returns: The CallKit UUID of the call.
        /// - Throws: The CallKit error when the system refuses the call.
        public func startOutgoingCall(to destination: String, displayName: String? = nil,
                                      video: Bool = false) async throws -> UUID {
            let uuid = UUID()
            try await requestOutgoingCall(uuid: uuid, to: destination, displayName: displayName, video: video)
            return uuid
        }

        func requestOutgoingCall(uuid: UUID, to destination: String, displayName: String?,
                                 video: Bool) async throws {
            let action = CXStartCallAction(call: uuid, handle: handle(for: destination))
            action.isVideo = video
            action.contactIdentifier = displayName
            lock.withLock { startDestinations[uuid] = destination }
            do {
                try await controller.request(CXTransaction(action: action))
            } catch {
                lock.withLock { startDestinations[uuid] = nil }
                throw error
            }
        }

        /// Answers an incoming call through CallKit.
        ///
        /// Use this when the app's own incoming call screen answers, so the system call screen stops
        /// ringing and CallKit activates the audio session. CallKit asks the adapter to perform the
        /// answer, which then calls `BaresipEngine.answer(callID:video:audio:)`.
        ///
        /// - Parameter uuid: The CallKit UUID of the call, from ``uuid(for:)``.
        /// - Throws: The CallKit error when the system refuses the request, or the engine's error when
        ///   the action fails on the call.
        public func answerCall(uuid: UUID) async throws {
            try await requestAndWait(CXAnswerCallAction(call: uuid))
        }

        /// Mutes or unmutes the microphone through CallKit, so the system call screen shows the
        /// same state as the app.
        ///
        /// - Parameters:
        ///   - muted: `true` to mute.
        ///   - uuid: The CallKit UUID of the call.
        /// - Throws: The CallKit error when the system refuses the request, or the engine's error when
        ///   the action fails on the call.
        public func setMuted(_ muted: Bool, uuid: UUID) async throws {
            try await requestAndWait(CXSetMutedCallAction(call: uuid, muted: muted))
        }

        /// Holds or resumes a call through CallKit, so the system call screen shows the same state
        /// as the app.
        ///
        /// - Parameters:
        ///   - onHold: `true` to hold.
        ///   - uuid: The CallKit UUID of the call.
        /// - Throws: The CallKit error when the system refuses the request, or the engine's error when
        ///   the action fails on the call.
        public func setHeld(_ onHold: Bool, uuid: UUID) async throws {
            try await requestAndWait(CXSetHeldCallAction(call: uuid, onHold: onHold))
        }

        /// Sets a handler called after the microphone of a call was muted or unmuted through CallKit,
        /// from the system call screen or ``setMuted(_:uuid:)``.
        ///
        /// The engine reports no event for muting, so use this to keep the app's mute button in step.
        /// The handler runs on an arbitrary thread.
        ///
        /// - Parameter handler: The handler, or `nil` to remove it.
        public func setMuteHandler(_ handler: (@Sendable (BaresipCallID, Bool) -> Void)?) {
            lock.withLock { muteHandler = handler }
        }

        /// Ends a call through CallKit.
        ///
        /// - Parameter uuid: The CallKit UUID of the call.
        /// - Throws: The CallKit error when the system refuses the request, or the engine's error when
        ///   the action fails on the call.
        public func endCall(uuid: UUID) async throws {
            try await requestAndWait(CXEndCallAction(call: uuid))
        }

        /// Requests an action and returns once the adapter carried it out on the engine, so a
        /// failure on the engine reaches the caller.
        func requestAndWait(_ action: CXCallAction) async throws {
            let id = action.uuid
            let box = UncheckedSendable(value: action)
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                lock.withLock { actionWaiters[id] = continuation }
                Task {
                    do {
                        try await controller.request(CXTransaction(action: box.value))
                    } catch {
                        takeActionWaiter(id)?.resume(throwing: error)
                    }
                }
            }
        }

        func takeActionWaiter(_ id: UUID) -> CheckedContinuation<Void, Error>? {
            lock.withLock { actionWaiters.removeValue(forKey: id) }
        }

        /// Fulfills or fails an action and tells a caller waiting in ``requestAndWait(_:)``.
        func complete(_ action: CXAction, error: Error?) {
            if let error {
                action.fail()
                takeActionWaiter(action.uuid)?.resume(throwing: error)
            } else {
                action.fulfill()
                takeActionWaiter(action.uuid)?.resume()
            }
        }

        /// The CallKit handle of a SIP URI, user name or number, as `BaresipHandleStyle` says.
        func handle(for address: String) -> CXHandle {
            if handleStyle == .phoneNumberWhenNumeric, let number = SIPIdentity(address).phoneNumber {
                return CXHandle(type: .phoneNumber, value: number)
            }
            return CXHandle(type: .generic, value: address)
        }

        func bind(_ call: BaresipCallID, _ uuid: UUID) {
            lock.withLock {
                uuidByCall[call] = uuid
                callByUUID[uuid] = call
            }
        }

        func unbind(_ call: BaresipCallID) -> UUID? {
            lock.withLock {
                guard let uuid = uuidByCall.removeValue(forKey: call) else { return nil }
                callByUUID[uuid] = nil
                pendingAnswers.remove(uuid)
                outgoing.remove(uuid)
                answerVideo[uuid] = nil
                return uuid
            }
        }

        func callID(for uuid: UUID) -> BaresipCallID? {
            lock.withLock { callByUUID[uuid] }
        }
    }
#endif
