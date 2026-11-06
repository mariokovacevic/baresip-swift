import CallKit
import Foundation
import PushKit
import BaresipKit

/// Registers for VoIP pushes and keeps the account's push `Contact` parameters current.
///
/// When a VoIP push arrives, the adapter calls your handler, which must report the call to
/// CallKit (for example with `BaresipCallKitAdapter.reportIncomingCallFromPush(uuid:remoteURI:displayName:hasVideo:)`), and then
/// wakes the engine so the INVITE can arrive. If the handler throws, the adapter reports and
/// ends a placeholder call, because iOS terminates apps that receive a VoIP push without
/// reporting a call.
///
/// ```swift
/// let push = BaresipPushKitAdapter(engine: engine, appID: "com.example.app") { payload in
///     try await callKit.reportIncomingCallFromPush(uuid: UUID(), remoteURI: payload["from"] as? String,
///                                                  displayName: nil, hasVideo: false)
/// }
/// push.bind(accountID: account)
/// ```
public final class BaresipPushKitAdapter: NSObject, PKPushRegistryDelegate, @unchecked Sendable {
    // SAFETY: `tokens`, `accountID` and the lazily created fallback provider are accessed only
    // while holding `lock`; the other properties are immutable.

    /// Called for each VoIP push with the push payload; must report a call to CallKit.
    public typealias IncomingPushHandler = @Sendable (_ payload: [AnyHashable: Any]) async throws -> Void

    private let engine: BaresipEngine
    private let registry: PKPushRegistry
    private let lock = NSLock()
    private var tokens: BaresipPushTokens
    private var accountID: BaresipAccountID?
    private let onIncomingPush: IncomingPushHandler
    private lazy var fallbackProvider = CXProvider(configuration: CXProviderConfiguration())

    /// Creates the adapter and registers for VoIP pushes.
    ///
    /// - Parameters:
    ///   - engine: The engine to wake for push calls.
    ///   - appID: The app's bundle identifier, sent as `app-id`.
    ///   - accountID: The account whose `Contact` parameters carry the tokens, if known yet.
    ///   - onIncomingPush: The handler that reports each push call to CallKit.
    public init(engine: BaresipEngine, appID: String, accountID: BaresipAccountID? = nil,
                onIncomingPush: @escaping IncomingPushHandler) {
        self.engine = engine
        self.tokens = BaresipPushTokens(appID: appID)
        self.accountID = accountID
        self.onIncomingPush = onIncomingPush
        self.registry = PKPushRegistry(queue: nil)
        super.init()
        registry.delegate = self
        registry.desiredPushTypes = [.voIP]
    }

    /// Sets the account that receives the push parameters and updates its registration.
    ///
    /// - Parameter accountID: The account.
    public func bind(accountID: BaresipAccountID) {
        lock.withLock {
            self.accountID = accountID
        }
        Task { await sendTokensToEngine() }
    }

    /// Adds the APNs token for regular remote notifications.
    ///
    /// - Parameter token: The token from `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`.
    public func updateRemoteToken(_ token: Data) {
        lock.withLock {
            tokens.remoteToken = token
        }
        Task { await sendTokensToEngine() }
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
        lock.withLock {
            tokens.voipToken = token
        }
        Task { await sendTokensToEngine() }
    }

    /// Removes the VoIP token and updates the account's registration.
    ///
    /// - Parameters:
    ///   - registry: The push registry.
    ///   - type: The push type.
    public func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        guard type == .voIP else { return }
        lock.withLock {
            tokens.voipToken = nil
        }
        Task { await sendTokensToEngine() }
    }

    /// Calls the push handler, then wakes the engine for the INVITE.
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
        let dictionary = UncheckedSendable(value: payload.dictionaryPayload)
        let done = UncheckedSendable(value: completion)
        Task {
            do {
                try await onIncomingPush(dictionary.value)
            } catch {
                await reportFailedPushCall()
            }
            try? await engine.prepareForPushWakeUp()
            done.value()
        }
    }

    private func sendTokensToEngine() async {
        let (account, parameters) = lock.withLock { (accountID, tokens.contactParameters) }
        guard let account else { return }
        try? await engine.updateContactParameters(accountID: account, parameters: parameters, reregisterNow: true)
    }

    private func reportFailedPushCall() async {
        let uuid = UUID()
        let provider = lock.withLock { fallbackProvider }
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: "unknown")
        try? await provider.reportNewIncomingCall(with: uuid, update: update)
        provider.reportCall(with: uuid, endedAt: Date(), reason: .failed)
    }
}
