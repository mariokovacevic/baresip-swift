import AVFoundation
import CallKit
import Foundation
import BaresipKit

extension BaresipCallKitAdapter: CXProviderDelegate {
    /// Hangs up every call after CallKit reset the provider.
    ///
    /// - Parameter provider: The provider.
    public func providerDidReset(_ provider: CXProvider) {
        let calls = lock.withLock { () -> [BaresipCallID] in
            let calls = Array(uuidByCall.keys)
            uuidByCall.removeAll()
            callByUUID.removeAll()
            pendingAnswers.removeAll()
            return calls
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
        let destination = action.handle.value
        let video = action.isVideo
        let uuid = action.callUUID
        Task {
            do {
                let id = try await engine.makeCall(destination: destination, video: video)
                lock.withLock { _ = outgoing.insert(uuid) }
                bind(id, uuid)
                box.value.fulfill()
                await reconcileOutgoing(id, uuid: uuid)
            } catch {
                box.value.fail()
            }
        }
    }

    /// Answers the call, or remembers the answer until the INVITE of a push call arrives.
    ///
    /// - Parameters:
    ///   - provider: The provider.
    ///   - action: The answer action.
    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        let uuid = action.callUUID
        let call = lock.withLock { () -> BaresipCallID? in
            let call = callByUUID[uuid]
            if call == nil {
                pendingAnswers.insert(uuid)
            }
            return call
        }
        guard let call else {
            action.fulfill()
            return
        }
        let box = UncheckedSendable(value: action)
        Task {
            do {
                let video = await (try? engine.callInfo(callID: call))?.hasVideo ?? false
                try await engine.answer(callID: call, video: video)
                box.value.fulfill()
            } catch {
                box.value.fail()
            }
        }
    }

    /// Hangs up the call.
    ///
    /// - Parameters:
    ///   - provider: The provider.
    ///   - action: The end action.
    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        let uuid = action.callUUID
        let call = lock.withLock { () -> BaresipCallID? in
            pendingAnswers.remove(uuid)
            pendingIncoming[uuid] = nil
            return callByUUID[uuid]
        }
        guard let call else {
            action.fulfill()
            return
        }
        let box = UncheckedSendable(value: action)
        Task {
            try? await engine.hangup(callID: call)
            box.value.fulfill()
        }
    }

    /// Holds or resumes the call.
    ///
    /// - Parameters:
    ///   - provider: The provider.
    ///   - action: The hold action.
    public func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        guard let call = callID(for: action.callUUID) else {
            action.fail()
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
            action.fail()
            return
        }
        let muted = action.isMuted
        perform(action) { engine in
            try await engine.setMicrophoneMuted(muted, callID: call)
        }
    }

    /// Sends the DTMF digits.
    ///
    /// - Parameters:
    ///   - provider: The provider.
    ///   - action: The DTMF action.
    public func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) {
        guard let call = callID(for: action.callUUID) else {
            action.fail()
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
                box.value.fulfill()
            } catch {
                box.value.fail()
            }
        }
    }
}
