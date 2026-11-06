import Foundation
import PushKit
import BaresipKit

public struct BaresipPushTokens: Sendable, Equatable {
    public var appID: String
    public var remoteToken: Data?
    public var voipToken: Data?
    public var platform: String
    public var silent: Bool
    public var timeout: Int
    public var channel: String?

    public init(appID: String, remoteToken: Data? = nil, voipToken: Data? = nil,
                platform: String = "apple", silent: Bool = true, timeout: Int = 0,
                channel: String? = nil) {
        self.appID = appID
        self.remoteToken = remoteToken
        self.voipToken = voipToken
        self.platform = platform
        self.silent = silent
        self.timeout = timeout
        self.channel = channel
    }

    public var combinedToken: String {
        var parts: [String] = []
        if let remoteToken {
            parts.append(Self.hex(remoteToken) + ":remote")
        }
        if let voipToken {
            parts.append(Self.hex(voipToken) + ":voip")
        }
        return parts.joined(separator: "&")
    }

    public var contactParameters: [ContactParameter] {
        var params: [ContactParameter] = [
            ContactParameter("app-id", appID),
            ContactParameter("pn-type", platform),
        ]
        let token = combinedToken
        if !token.isEmpty {
            params.append(ContactParameter("pn-tok", token))
        }
        params.append(ContactParameter("pn-silent", silent ? "1" : "0"))
        params.append(ContactParameter("pn-timeout", String(timeout)))
        if let channel {
            params.append(ContactParameter("pn-channel", channel))
        }
        return params
    }

    static func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}

public final class BaresipPushKitAdapter: NSObject, PKPushRegistryDelegate, @unchecked Sendable {
    public typealias IncomingPushHandler = @Sendable (_ payload: [AnyHashable: Any]) async -> Void

    private let engine: BaresipEngine
    private let registry: PKPushRegistry
    private let lock = NSLock()
    private var tokens: BaresipPushTokens
    private var accountID: BaresipAccountID?
    private let onIncomingPush: IncomingPushHandler

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

    public func bind(accountID: BaresipAccountID) {
        lock.lock()
        self.accountID = accountID
        lock.unlock()
        Task { await pushTokensToEngine() }
    }

    public func updateRemoteToken(_ token: Data) {
        lock.lock()
        tokens.remoteToken = token
        lock.unlock()
        Task { await pushTokensToEngine() }
    }

    public var currentTokens: BaresipPushTokens {
        lock.lock(); defer { lock.unlock() }
        return tokens
    }

    private func pushTokensToEngine() async {
        let (account, params) = lock.withLock { (accountID, tokens.contactParameters) }
        guard let account else { return }
        try? await engine.updateContactParameters(accountID: account, parameters: params, reregisterNow: true)
    }

    public func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials,
                             for type: PKPushType) {
        guard type == .voIP else { return }
        lock.lock()
        tokens.voipToken = pushCredentials.token
        lock.unlock()
        Task { await pushTokensToEngine() }
    }

    public func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        guard type == .voIP else { return }
        lock.lock()
        tokens.voipToken = nil
        lock.unlock()
        Task { await pushTokensToEngine() }
    }

    public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload,
                             for type: PKPushType, completion: @escaping () -> Void) {
        guard type == .voIP else {
            completion()
            return
        }
        let dictionary = payload.dictionaryPayload
        Task {
            await onIncomingPush(dictionary)
            try? await engine.prepareForPushWakeUp()
            completion()
        }
    }
}
