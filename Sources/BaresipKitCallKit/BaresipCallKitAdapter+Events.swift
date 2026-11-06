import CallKit
import Foundation
import BaresipKit

extension BaresipCallKitAdapter {
    static let busyStatusCode = 486
    static let declineStatusCode = 600

    func handle(_ event: BaresipEvent) async {
        switch event {
        case .incomingCall(let info, _):
            await handleIncoming(info)
        case .call(let call, let state, let error):
            handleState(state, of: call, error: error)
        default:
            break
        }
    }

    private func handleIncoming(_ info: BaresipCallInfo) async {
        if let uuid = takePendingPushCall(matching: info.remoteURI) {
            bind(info.id, uuid)
            let answerNow = lock.withLock { pendingAnswers.contains(uuid) }
            if answerNow {
                try? await engine.answer(callID: info.id, video: info.hasVideo)
            }
            return
        }
        let uuid = UUID()
        bind(info.id, uuid)
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: info.remoteURI)
        update.localizedCallerName = info.remoteDisplayName.isEmpty ? nil : info.remoteDisplayName
        update.hasVideo = info.hasVideo
        do {
            try await provider.reportNewIncomingCall(with: uuid, update: update)
        } catch {
            try? await engine.reject(callID: info.id, statusCode: Self.busyStatusCode)
        }
    }

    private func handleState(_ state: BaresipCallState, of call: BaresipCallID, error: BaresipError?) {
        guard let uuid = uuid(for: call) else { return }
        let isOutgoing = lock.withLock { outgoing.contains(uuid) }
        switch state {
        case .outgoingRinging, .earlyMedia:
            if isOutgoing {
                provider.reportOutgoingCall(with: uuid, startedConnectingAt: Date())
            }
        case .connected, .streamsRunning:
            if isOutgoing {
                provider.reportOutgoingCall(with: uuid, connectedAt: Date())
            }
        case .ended, .failed:
            provider.reportCall(with: uuid, endedAt: Date(), reason: Self.endedReason(for: error))
        case .released:
            _ = unbind(call)
        default:
            break
        }
    }

    static func endedReason(for error: BaresipError?) -> CXCallEndedReason {
        guard let error else { return .remoteEnded }
        if error.sipStatus == busyStatusCode || error.sipStatus == declineStatusCode {
            return .unanswered
        }
        return .failed
    }

    func reconcileOutgoing(_ call: BaresipCallID, uuid: UUID) async {
        do {
            let info = try await engine.callInfo(callID: call)
            switch info.state {
            case .outgoingRinging, .earlyMedia:
                provider.reportOutgoingCall(with: uuid, startedConnectingAt: Date())
            case .connected, .streamsRunning:
                provider.reportOutgoingCall(with: uuid, connectedAt: Date())
            case .ended, .failed, .released:
                provider.reportCall(with: uuid, endedAt: Date(), reason: .failed)
            default:
                break
            }
        } catch {
            if unbind(call) != nil {
                provider.reportCall(with: uuid, endedAt: Date(), reason: .failed)
            }
        }
    }
}
