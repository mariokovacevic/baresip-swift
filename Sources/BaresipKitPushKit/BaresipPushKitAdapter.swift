#if os(iOS)
    import CallKit
    import Foundation
    import PushKit
    import BaresipKit
    import BaresipKitSystemCall

    /// Registers for VoIP pushes and keeps the account's push `Contact` parameters current.
    ///
    /// When a VoIP push arrives, the adapter calls your handler on the main queue, inside the
    /// PushKit delegate method. The handler must report the call to CallKit before it returns,
    /// for example with
    /// `BaresipCallKitAdapter.reportIncomingCallFromPush(uuid:remoteURI:displayName:hasVideo:completion:)`:
    /// iOS terminates an app that returns from the delegate method without a reported call. If
    /// the handler throws, the adapter reports and ends a placeholder call before the delegate
    /// method returns. Afterwards the adapter wakes the engine so the INVITE can arrive.
    ///
    /// LiveCommunicationKit reports calls only asynchronously. With
    /// `BaresipLiveCommunicationAdapter`, create the adapter with
    /// ``reportingAsynchronously(engine:appID:accountID:additionalContactParameters:onIncomingPush:)``:
    /// the push is completed only after the asynchronous handler returned.
    ///
    /// The adapter owns the `Contact` parameters of the bound account: every update replaces all
    /// of them, including those from `BaresipAccountConfiguration.contactParameters`. Pass the
    /// parameters the account needs besides the push ones as `additionalContactParameters`.
    ///
    /// ```swift
    /// let push = BaresipPushKitAdapter(engine: engine, appID: "com.example.app") { payload in
    ///     callKit.reportIncomingCallFromPush(uuid: nil, remoteURI: payload["from"] as? String,
    ///                                        displayName: nil, hasVideo: false) { _ in }
    /// }
    /// push.bind(accountID: account)
    /// ```
    public final class BaresipPushKitAdapter: NSObject, PKPushRegistryDelegate, @unchecked Sendable {
        // SAFETY: `tokens`, `additionalParameters`, `accountID`, `updates` and `errorHandler` are
        // accessed only while holding `lock`; the other properties are immutable.

        /// Called for each VoIP push with the push payload.
        ///
        /// The handler runs on the main queue, inside the PushKit delegate method. It must report
        /// a call to CallKit before it returns, without starting a task or awaiting anything, and
        /// throw when it cannot report one.
        public typealias IncomingPushHandler = @Sendable (_ payload: [AnyHashable: Any]) throws -> Void

        /// Called for each VoIP push with the push payload, for system call interfaces that report
        /// calls asynchronously, such as LiveCommunicationKit.
        ///
        /// The adapter completes the push only after the handler returned. The handler must have
        /// reported a call by then, and throw when it cannot report one.
        public typealias AsyncIncomingPushHandler = @Sendable (_ payload: [AnyHashable: Any]) async throws -> Void

        private enum PushHandler {
            case immediate(IncomingPushHandler)
            case awaited(AsyncIncomingPushHandler)
        }

        /// What the adapter was doing when an error occurred; see
        /// ``BaresipPushKitAdapter/setErrorHandler(_:)``.
        public enum Step: Sendable {
            /// Sending the `Contact` parameters to the engine. The account keeps its previous
            /// parameters until the next update.
            case contactParameters
            /// Reporting a push to the system. The handler threw, and a placeholder call was
            /// reported.
            case incomingPush
            /// Waking the engine after a push. The INVITE may not arrive.
            case engineWakeUp
        }

        /// Called with the errors of work the adapter does on its own; see
        /// ``BaresipPushKitAdapter/setErrorHandler(_:)``.
        public typealias ErrorHandler = @Sendable (_ step: Step, _ error: Error) -> Void

        private let engine: BaresipEngine
        private let registry: PKPushRegistry
        private let lock = NSLock()
        private var tokens: BaresipPushTokens
        private var additionalParameters: [BaresipContactParameter]
        private var accountID: BaresipAccountID?
        private var updates = ContactParameterUpdates()
        private var errorHandler: ErrorHandler?
        private let onIncomingPush: PushHandler

        /// Creates the adapter and registers for VoIP pushes.
        ///
        /// - Parameters:
        ///   - engine: The engine to wake for push calls.
        ///   - appID: The app's bundle identifier, sent as `app-id`.
        ///   - accountID: The account whose `Contact` parameters carry the tokens, if known yet.
        ///   - additionalContactParameters: `Contact` parameters sent together with the push ones. A
        ///     parameter with the name of a push parameter is left out.
        ///   - onIncomingPush: The handler that reports each push call to CallKit before it returns.
        public convenience init(engine: BaresipEngine, appID: String, accountID: BaresipAccountID? = nil,
                                additionalContactParameters: [BaresipContactParameter] = [],
                                onIncomingPush: @escaping IncomingPushHandler) {
            self.init(engine: engine, appID: appID, accountID: accountID,
                      additionalContactParameters: additionalContactParameters, handler: .immediate(onIncomingPush))
        }

        /// Creates an adapter for a system call interface that reports calls asynchronously, such
        /// as LiveCommunicationKit, and registers for VoIP pushes.
        ///
        /// ```swift
        /// let push = BaresipPushKitAdapter.reportingAsynchronously(engine: engine, appID: appID) { payload in
        ///     try await calls.reportIncomingCallFromPush(uuid: nil, remoteURI: payload["from"] as? String,
        ///                                                displayName: nil, hasVideo: false)
        /// }
        /// ```
        ///
        /// - Parameters:
        ///   - engine: The engine to wake for push calls.
        ///   - appID: The app's bundle identifier, sent as `app-id`.
        ///   - accountID: The account whose `Contact` parameters carry the tokens, if known yet.
        ///   - additionalContactParameters: `Contact` parameters sent together with the push ones. A
        ///     parameter with the name of a push parameter is left out.
        ///   - onIncomingPush: The handler that reports each push call; the push is completed after
        ///     it returned.
        /// - Returns: The adapter.
        public static func reportingAsynchronously(engine: BaresipEngine, appID: String,
                                                   accountID: BaresipAccountID? = nil,
                                                   additionalContactParameters: [BaresipContactParameter] = [],
                                                   onIncomingPush: @escaping AsyncIncomingPushHandler)
            -> BaresipPushKitAdapter {
            BaresipPushKitAdapter(engine: engine, appID: appID, accountID: accountID,
                                  additionalContactParameters: additionalContactParameters,
                                  handler: .awaited(onIncomingPush))
        }

        private init(engine: BaresipEngine, appID: String, accountID: BaresipAccountID?,
                     additionalContactParameters: [BaresipContactParameter], handler: PushHandler) {
            self.engine = engine
            tokens = BaresipPushTokens(appID: appID)
            additionalParameters = additionalContactParameters
            self.accountID = accountID
            onIncomingPush = handler
            registry = PKPushRegistry(queue: nil)
            super.init()
            registry.delegate = self
            registry.desiredPushTypes = [.voIP]
        }

        /// Sets a handler for the errors of work the adapter does on its own: updating the
        /// account's `Contact` parameters, handling a push and waking the engine.
        ///
        /// Without a handler these errors are dropped. The handler runs on an arbitrary thread.
        ///
        /// - Parameter handler: The handler, or `nil` to remove it.
        public func setErrorHandler(_ handler: ErrorHandler?) {
            lock.withLock {
                errorHandler = handler
            }
        }

        /// Sets the account that receives the push parameters and updates its registration.
        ///
        /// - Parameter accountID: The account.
        public func bind(accountID: BaresipAccountID) {
            lock.withLock {
                self.accountID = accountID
            }
            sendContactParameters()
        }

        /// Changes the `app-id` sent to the server, for example to switch between push environments,
        /// and updates the account's registration.
        ///
        /// - Parameter appID: The new `app-id`.
        public func updateAppID(_ appID: String) {
            updateTokens { $0.appID = appID }
        }

        /// Adds the APNs token for regular remote notifications and updates the account's
        /// registration.
        ///
        /// - Parameter token: The token from `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`.
        public func updateRemoteToken(_ token: Data) {
            updateTokens { $0.remoteToken = token }
        }

        /// Replaces the `Contact` parameters sent together with the push ones and updates the
        /// account's registration.
        ///
        /// - Parameter parameters: The new additional parameters. A parameter with the name of a
        ///   push parameter is left out.
        public func updateAdditionalContactParameters(_ parameters: [BaresipContactParameter]) {
            let changed = lock.withLock { () -> Bool in
                guard additionalParameters != parameters else { return false }
                additionalParameters = parameters
                return true
            }
            if changed {
                sendContactParameters()
            }
        }

        /// The current tokens.
        public var currentTokens: BaresipPushTokens {
            lock.withLock { tokens }
        }

        /// Stores the new VoIP token and updates the account's registration.
        ///
        /// - Parameters:
        ///   - registry: The push registry.
        ///   - pushCredentials: The new credentials.
        ///   - type: The push type.
        public func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials,
                                 for type: PKPushType) {
            guard type == .voIP else { return }
            let token = pushCredentials.token
            updateTokens { $0.voipToken = token }
        }

        /// Removes the VoIP token and updates the account's registration.
        ///
        /// - Parameters:
        ///   - registry: The push registry.
        ///   - type: The push type.
        public func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
            guard type == .voIP else { return }
            updateTokens { $0.voipToken = nil }
        }

        /// Calls the push handler, then wakes the engine for the INVITE.
        ///
        /// A synchronous handler runs before this method returns, an asynchronous one before the
        /// completion handler runs. When the handler throws, a placeholder call is reported and
        /// ended, so iOS always sees a reported call for the push.
        ///
        /// - Parameters:
        ///   - registry: The push registry.
        ///   - payload: The push payload.
        ///   - type: The push type.
        ///   - completion: Called after the call was reported and the engine woken.
        public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload,
                                 for type: PKPushType, completion: @escaping () -> Void) {
            guard type == .voIP else {
                completion()
                return
            }
            let done = UncheckedSendable(value: completion)
            switch onIncomingPush {
            case .immediate(let handler):
                let failure = IncomingPushReport.deliver(payload.dictionaryPayload, to: handler,
                                                         orReportPlaceholder: Self.reportPlaceholderCall)
                if let failure {
                    report(.incomingPush, failure)
                }
                Task {
                    await wakeEngine()
                    done.value()
                }
            case .awaited(let handler):
                let dictionary = UncheckedSendable(value: payload.dictionaryPayload)
                Task {
                    do {
                        try await handler(dictionary.value)
                    } catch {
                        Self.reportPlaceholderCall()
                        report(.incomingPush, error)
                    }
                    await wakeEngine()
                    done.value()
                }
            }
        }

        private func wakeEngine() async {
            do {
                try await engine.prepareForPushWakeUp()
            } catch {
                report(.engineWakeUp, error)
            }
        }

        private func updateTokens(_ change: (inout BaresipPushTokens) -> Void) {
            let changed = lock.withLock { () -> Bool in
                let previous = tokens
                change(&tokens)
                return tokens != previous
            }
            if changed {
                sendContactParameters()
            }
        }

        private func sendContactParameters() {
            let startsSending = lock.withLock { () -> Bool in
                guard let accountID else { return false }
                let parameters = tokens.mergedContactParameters(with: additionalParameters)
                return updates.submit(ContactParameterUpdates.Request(accountID: accountID, parameters: parameters))
            }
            if startsSending {
                Task { await sendPendingContactParameters() }
            }
        }

        private func sendPendingContactParameters() async {
            while true {
                let request = lock.withLock { updates.next() }
                guard let request else { return }
                do {
                    try await engine.updateContactParameters(accountID: request.accountID,
                                                             parameters: request.parameters, reregisterNow: true)
                } catch {
                    report(.contactParameters, error)
                }
            }
        }

        private func report(_ step: Step, _ error: Error) {
            let handler = lock.withLock { errorHandler }
            handler?(step, error)
        }

        private static func reportPlaceholderCall() {
            let configuration = CXProviderConfiguration()
            configuration.includesCallsInRecents = false
            configuration.supportsVideo = false
            let provider = UncheckedSendable(value: CXProvider(configuration: configuration))
            let uuid = UUID()
            let update = CXCallUpdate()
            update.remoteHandle = CXHandle(type: .generic, value: "unknown")
            provider.value.reportNewIncomingCall(with: uuid, update: update) { error in
                if error == nil {
                    provider.value.reportCall(with: uuid, endedAt: Date(), reason: .failed)
                }
                provider.value.invalidate()
            }
        }
    }
#endif
