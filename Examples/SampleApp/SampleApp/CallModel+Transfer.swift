import Foundation
import BaresipKit

extension CallModel {
    func endConsultation() async {
        guard heldCall != nil, let currentCall else { return }
        try? await engine?.hangup(callID: currentCall)
    }


    func blindTransfer() async {
        guard let engine, let currentCall else { return }
        let target = normalizedDestination(transferTarget)
        guard !target.isEmpty else { return }
        do {
            try await engine.transfer(callID: currentCall, to: target)
            append("transferring \(currentCall) to \(target)")
        } catch {
            append("transfer failed: \(error)")
        }
    }

    func consult() async {
        guard let engine, let currentCall, heldCall == nil else { return }
        let target = normalizedDestination(transferTarget)
        guard !target.isEmpty else { return }
        do {
            try await engine.hold(callID: currentCall)
            heldCall = currentCall
            onHold = false
            _ = try await engine.makeCall(accountID: accountID, destination: target, video: false)
            append("consulting \(target) while \(currentCall) is on hold")
        } catch {
            append("consultation failed: \(error)")
        }
    }

    func completeTransfer() async {
        guard let engine, let heldCall, let currentCall, heldCall != currentCall else { return }
        do {
            try await engine.transferAttended(callID: heldCall, to: currentCall)
            append("attended transfer of \(heldCall) to \(currentCall)")
        } catch {
            append("attended transfer failed: \(error)")
        }
    }
}
