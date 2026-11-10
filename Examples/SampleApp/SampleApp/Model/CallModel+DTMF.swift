import Foundation
import BaresipKit
import BaresipKitSwiftUI

extension CallModel {
    /// Sends DTMF the way a door station expects it: on the current call, or on a new audio
    /// call to the entered address once it is connected.
    func sendDTMFRequest(_ request: DTMFRequest) async {
        guard let activeCall else {
            pendingDTMF = request
            await call(video: false)
            return
        }
        dtmfStates[activeCall.id] = DTMFState(request: request)
        if activeCall.state == .streamsRunning {
            sendQueuedDTMF(activeCall.id)
        }
    }

    /// Sends the call's DTMF once and, if the request expects one, waits for the station's reply.
    func sendQueuedDTMF(_ call: BaresipCallID) {
        guard var state = dtmfStates[call], !state.sent, let target = phone?.call(call) else { return }
        state.sent = true
        dtmfStates[call] = state
        let request = state.request
        Task { [weak self] in
            let result: String
            do {
                if let reply = request.ack.first {
                    switch try await target.sendDTMF(request.digits, expectingReply: reply,
                                                     timeout: DTMFRequest.ackTimeout) {
                    case .confirmed: result = "door opened"
                    case .other(let digit): result = "reply \(digit), expected \(reply)"
                    case .noReply: result = "no reply"
                    }
                } else {
                    try await target.sendDTMF(request.digits)
                    result = "sent"
                }
                self?.append("sent DTMF \(request.digits)")
            } catch {
                result = "failed: \(error)"
            }
            await self?.finishDTMF(call, result: result)
        }
    }

    /// Records the outcome once and hangs up if the request asked for it.
    func finishDTMF(_ call: BaresipCallID, result: String) async {
        guard var state = dtmfStates[call], state.result == nil else { return }
        state.result = result
        dtmfStates[call] = state
        append("DTMF \(state.request.digits): \(result)")
        guard state.request.hangUp else { return }
        try? await Task.sleep(for: DTMFRequest.hangUpDelay)
        await hangup(call)
    }

    func sendDTMF(_ digits: String) async {
        try? await activeCall?.sendDTMF(digits)
    }
}
