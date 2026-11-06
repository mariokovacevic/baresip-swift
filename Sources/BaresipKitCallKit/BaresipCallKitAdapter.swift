import Foundation
import AVFoundation
import CallKit
import BaresipKit

public struct BaresipCallKitConfiguration: Sendable {
    @available(*, deprecated, message: "CXProviderConfiguration.localizedName is read-only in current SDKs; CallKit shows the app name from the Info.plist.")
    public var localizedName: String = ""
    public var supportsVideo: Bool
    public var maximumCallsPerCallGroup: Int
    public var iconTemplateImageData: Data?
    public var ringtoneSound: String?

    public init(supportsVideo: Bool = true, maximumCallsPerCallGroup: Int = 1,
                iconTemplateImageData: Data? = nil, ringtoneSound: String? = nil) {
        self.supportsVideo = supportsVideo
        self.maximumCallsPerCallGroup = maximumCallsPerCallGroup
        self.iconTemplateImageData = iconTemplateImageData
        self.ringtoneSound = ringtoneSound
    }

    @available(*, deprecated, message: "localizedName has no effect; use init(supportsVideo:maximumCallsPerCallGroup:iconTemplateImageData:ringtoneSound:)")
    public init(localizedName: String, supportsVideo: Bool = true, maximumCallsPerCallGroup: Int = 1,
                iconTemplateImageData: Data? = nil, ringtoneSound: String? = nil) {
        self.init(supportsVideo: supportsVideo, maximumCallsPerCallGroup: maximumCallsPerCallGroup,
                  iconTemplateImageData: iconTemplateImageData, ringtoneSound: ringtoneSound)
        self.localizedName = localizedName
    }
}

public final class BaresipCallKitAdapter: NSObject, CXProviderDelegate, @unchecked Sendable {
    private let engine: BaresipEngine
    private let provider: CXProvider
    private let controller = CXCallController()
    private let lock = NSLock()
    private var uuidByCall: [BaresipCallID: UUID] = [:]
    private var callByUUID: [UUID: BaresipCallID] = [:]
    private var pendingAnswers: Set<UUID> = []
    private var pendingIncoming: [UUID: (remoteURI: String?, video: Bool)] = [:]
    private var eventTask: Task<Void, Never>?

    public init(engine: BaresipEngine, configuration: BaresipCallKitConfiguration) {
        self.engine = engine
        let cxConfig = CXProviderConfiguration()
        cxConfig.supportsVideo = configuration.supportsVideo
        cxConfig.maximumCallsPerCallGroup = configuration.maximumCallsPerCallGroup
        cxConfig.supportedHandleTypes = [.generic, .phoneNumber]
        cxConfig.iconTemplateImageData = configuration.iconTemplateImageData
        cxConfig.ringtoneSound = configuration.ringtoneSound
        provider = CXProvider(configuration: cxConfig)
        super.init()
        provider.setDelegate(self, queue: nil)
        eventTask = Task { [weak self] in
            guard let self else { return }
            for await event in engine.events {
                await self.handle(event)
            }
        }
    }

    deinit {
        eventTask?.cancel()
        provider.invalidate()
    }

    public func uuid(for call: BaresipCallID) -> UUID? {
        lock.lock(); defer { lock.unlock() }
        return uuidByCall[call]
    }

    public func reportIncomingCallFromPush(uuid: UUID, remoteURI: String?, displayName: String?,
                                           hasVideo: Bool) async throws {
        lock.withLock {
            pendingIncoming[uuid] = (remoteURI, hasVideo)
        }
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: remoteURI ?? "unknown")
        update.localizedCallerName = displayName
        update.hasVideo = hasVideo
        try await provider.reportNewIncomingCall(with: uuid, update: update)
    }

    public func startOutgoingCall(to destination: String, displayName: String? = nil,
                                  video: Bool = false) async throws -> UUID {
        let uuid = UUID()
        let handle = CXHandle(type: .generic, value: destination)
        let action = CXStartCallAction(call: uuid, handle: handle)
        action.isVideo = video
        action.contactIdentifier = displayName
        try await controller.request(CXTransaction(action: action))
        return uuid
    }

    public func endCall(uuid: UUID) async throws {
        try await controller.request(CXTransaction(action: CXEndCallAction(call: uuid)))
    }

    private func bind(_ call: BaresipCallID, _ uuid: UUID) {
        lock.lock()
        uuidByCall[call] = uuid
        callByUUID[uuid] = call
        lock.unlock()
    }

    private func unbind(_ call: BaresipCallID) -> UUID? {
        lock.lock(); defer { lock.unlock() }
        guard let uuid = uuidByCall.removeValue(forKey: call) else { return nil }
        callByUUID[uuid] = nil
        pendingAnswers.remove(uuid)
        return uuid
    }

    private func handle(_ event: BaresipEvent) async {
        switch event {
        case .incomingCall(let info, _):
            let matched: UUID? = lock.withLock {
                guard let (uuid, _) = pendingIncoming.first(where: { pair in
                    pair.value.remoteURI == nil || info.remoteURI.contains(pair.value.remoteURI ?? "")
                }) else { return nil }
                pendingIncoming[uuid] = nil
                return uuid
            }
            if let uuid = matched {
                bind(info.id, uuid)
                let answerNow = lock.withLock { pendingAnswers.contains(uuid) }
                if answerNow {
                    try? await engine.answer(callID: info.id, video: info.hasVideo)
                }
            } else {
                let uuid = UUID()
                bind(info.id, uuid)
                let update = CXCallUpdate()
                update.remoteHandle = CXHandle(type: .generic, value: info.remoteURI)
                update.localizedCallerName = info.remoteDisplayName.isEmpty ? nil : info.remoteDisplayName
                update.hasVideo = info.hasVideo
                do {
                    try await provider.reportNewIncomingCall(with: uuid, update: update)
                } catch {
                    try? await engine.reject(callID: info.id, statusCode: 486)
                }
            }
        case .call(let call, let state, let error):
            guard let uuid = uuid(for: call) else { return }
            switch state {
            case .outgoingRinging, .earlyMedia:
                provider.reportOutgoingCall(with: uuid, startedConnectingAt: Date())
            case .connected, .streamsRunning:
                provider.reportOutgoingCall(with: uuid, connectedAt: Date())
            case .ended, .failed:
                let reason: CXCallEndedReason
                if let error, error.sipStatus == 486 || error.sipStatus == 600 {
                    reason = .unanswered
                } else if error != nil {
                    reason = .failed
                } else {
                    reason = .remoteEnded
                }
                provider.reportCall(with: uuid, endedAt: Date(), reason: reason)
            case .released:
                _ = unbind(call)
            default:
                break
            }
        default:
            break
        }
    }

    public func providerDidReset(_ provider: CXProvider) {
        lock.lock()
        let calls = Array(uuidByCall.keys)
        uuidByCall.removeAll()
        callByUUID.removeAll()
        pendingAnswers.removeAll()
        lock.unlock()
        Task {
            for call in calls {
                try? await engine.hangup(callID: call)
            }
            await engine.audioSessionDidDeactivate()
        }
    }

    public func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        Task {
            do {
                let id = try await engine.makeCall(destination: action.handle.value, video: action.isVideo)
                bind(id, action.callUUID)
                action.fulfill()
            } catch {
                action.fail()
            }
        }
    }

    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        lock.lock()
        let call = callByUUID[action.callUUID]
        if call == nil {
            pendingAnswers.insert(action.callUUID)
        }
        lock.unlock()
        guard let call else {
            action.fulfill()
            return
        }
        Task {
            do {
                try await engine.answer(callID: call, video: false)
                action.fulfill()
            } catch {
                action.fail()
            }
        }
    }

    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        lock.lock()
        let call = callByUUID[action.callUUID]
        pendingAnswers.remove(action.callUUID)
        pendingIncoming[action.callUUID] = nil
        lock.unlock()
        guard let call else {
            action.fulfill()
            return
        }
        Task {
            try? await engine.hangup(callID: call)
            action.fulfill()
        }
    }

    public func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        guard let call = callID(for: action.callUUID) else {
            action.fail()
            return
        }
        Task {
            do {
                if action.isOnHold {
                    try await engine.hold(callID: call)
                } else {
                    try await engine.resume(callID: call)
                }
                action.fulfill()
            } catch {
                action.fail()
            }
        }
    }

    public func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        guard let call = callID(for: action.callUUID) else {
            action.fail()
            return
        }
        Task {
            do {
                try await engine.setMicrophoneMuted(action.isMuted, callID: call)
                action.fulfill()
            } catch {
                action.fail()
            }
        }
    }

    public func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) {
        guard let call = callID(for: action.callUUID) else {
            action.fail()
            return
        }
        Task {
            do {
                try await engine.sendDTMF(callID: call, digits: action.digits)
                action.fulfill()
            } catch {
                action.fail()
            }
        }
    }

    public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        Task {
            await engine.audioSessionDidActivate()
        }
    }

    public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        Task {
            await engine.audioSessionDidDeactivate()
        }
    }

    private func callID(for uuid: UUID) -> BaresipCallID? {
        lock.lock(); defer { lock.unlock() }
        return callByUUID[uuid]
    }
}
