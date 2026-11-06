import CallKit
import Foundation
import BaresipKit

/// Connects a `BaresipEngine` to CallKit.
///
/// The adapter reports incoming calls to the system call screen, starts outgoing calls through
/// `CXCallController`, and carries out the user's actions (answer, end, hold, mute, DTMF) on
/// the engine. Calls announced by a VoIP push are matched to the INVITE that follows.
///
/// ```swift
/// let callKit = BaresipCallKitAdapter(engine: engine, configuration: BaresipCallKitConfiguration())
/// let uuid = try await callKit.startOutgoingCall(to: "sip:bob@example.com")
/// ```
public final class BaresipCallKitAdapter: NSObject, @unchecked Sendable {
    // SAFETY: the mutable dictionaries and sets are read and written only while holding `lock`;
    // CXProvider and CXCallController are thread-safe.

    let engine: BaresipEngine
    let provider: CXProvider
    let controller = CXCallController()
    let pushInviteTimeout: Duration
    let lock = NSLock()
    var uuidByCall: [BaresipCallID: UUID] = [:]
    var callByUUID: [UUID: BaresipCallID] = [:]
    var pendingAnswers: Set<UUID> = []
    var outgoing: Set<UUID> = []
    var pendingIncoming: [UUID: (remoteURI: String?, video: Bool)] = [:]
    private var eventTask: Task<Void, Never>?

    /// Creates the adapter and its CallKit provider, and starts following engine events.
    ///
    /// - Parameters:
    ///   - engine: The engine whose calls are shown in CallKit.
    ///   - configuration: CallKit settings.
    public init(engine: BaresipEngine, configuration: BaresipCallKitConfiguration) {
        self.engine = engine
        self.pushInviteTimeout = configuration.pushInviteTimeout
        let providerConfiguration = CXProviderConfiguration()
        providerConfiguration.supportsVideo = configuration.supportsVideo
        providerConfiguration.maximumCallsPerCallGroup = configuration.maximumCallsPerCallGroup
        providerConfiguration.supportedHandleTypes = [.generic, .phoneNumber]
        providerConfiguration.iconTemplateImageData = configuration.iconTemplateImageData
        providerConfiguration.ringtoneSound = configuration.ringtoneSound
        provider = CXProvider(configuration: providerConfiguration)
        super.init()
        provider.setDelegate(self, queue: nil)
        eventTask = Task { [weak self] in
            for await event in engine.events {
                await self?.handle(event)
            }
        }
    }

    deinit {
        eventTask?.cancel()
        provider.invalidate()
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
    /// `BaresipEngine.makeCall(accountID:destination:video:)`.
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
        let action = CXStartCallAction(call: uuid, handle: CXHandle(type: .generic, value: destination))
        action.isVideo = video
        action.contactIdentifier = displayName
        try await controller.request(CXTransaction(action: action))
        return uuid
    }

    /// Ends a call through CallKit.
    ///
    /// - Parameter uuid: The CallKit UUID of the call.
    /// - Throws: The CallKit error when the system refuses the request.
    public func endCall(uuid: UUID) async throws {
        try await controller.request(CXTransaction(action: CXEndCallAction(call: uuid)))
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
            return uuid
        }
    }

    func callID(for uuid: UUID) -> BaresipCallID? {
        lock.withLock { callByUUID[uuid] }
    }
}
