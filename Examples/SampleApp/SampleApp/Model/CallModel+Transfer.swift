import Foundation
import BaresipKit

extension CallModel {
    /// Ends the consultation; `BaresipPhone` then resumes the held call.
    func endConsultation() async {
        guard heldCall != nil else { return }
        try? await activeCall?.hangUp()
    }

    func blindTransfer() async {
        guard let engine, let currentCall else { return }
        let target = normalizedDestination(transferTarget)
        guard !target.isEmpty else { return }
        do {
            try await engine.blindTransfer(callID: currentCall, to: target)
            append("transferring \(currentCall) to \(target)")
        } catch {
            append("transfer failed: \(error)")
        }
    }

    func consult() async {
        guard let phone, let active = activeCall, heldCall == nil else { return }
        let target = normalizedDestination(transferTarget)
        guard !target.isEmpty else { return }
        do {
            try await active.setOnHold(true)
            let consultation = try await phone.makeCall(to: target)
            try await phone.makeActive(consultation)
            append("consulting \(target) while \(active.id) is on hold")
        } catch {
            append("consultation failed: \(error)")
        }
    }

    func completeTransfer() async {
        guard let engine, let heldCall, let currentCall, heldCall != currentCall else { return }
        do {
            try await engine.attendedTransfer(callID: heldCall, replacing: currentCall)
            append("attended transfer of \(heldCall) to \(currentCall)")
        } catch {
            append("attended transfer failed: \(error)")
        }
    }
}
