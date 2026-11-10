import Foundation
import BaresipKit
import BaresipKitAudio
import BaresipKitSwiftUI

extension CallModel {
    /// Places a call. `BaresipPhone` sends it through CallKit on a device and to the engine in
    /// the simulator and in UI tests.
    func call(video: Bool) async {
        let target = normalizedDestination(destination)
        guard !target.isEmpty, let phone else {
            pendingDTMF = nil
            return
        }
        callMinimized = false
        await activatePreviewAudio()
        do {
            let call = try await phone.makeCall(to: target, video: video)
            if let pendingDTMF {
                dtmfStates[call.id] = DTMFState(request: pendingDTMF)
                self.pendingDTMF = nil
                if call.state == .streamsRunning {
                    sendQueuedDTMF(call.id)
                }
            }
        } catch {
            pendingDTMF = nil
            append("call failed: \(error)")
        }
    }

    /// Outgoing calls skip CallKit in UI tests and in the simulator, where CallKit never
    /// activates the audio session and ends its call when the app activates it instead.

    var usesDirectCalls: Bool {
        #if targetEnvironment(simulator)
            return true
        #else
            return uiTest
        #endif
    }

    func answer() async {
        guard let incoming else { return }
        do {
            try await incoming.answer(video: (incoming.hasVideo || incomingEarlyVideo) && answerWithCamera)
        } catch {
            append("answer failed: \(error)")
            return
        }
        didAnswer(incoming.id)
    }

    /// Moves the app from the incoming screen to the call, whichever screen answered.

    func didAnswer(_ call: BaresipCallID) {
        guard answeredCalls.insert(call).inserted else { return }
        snapshots.capture(call)
        callMinimized = false
        previewing = false
        previewVideo = false
        incomingEarlyVideo = false
        if shownIncoming == call {
            shownIncoming = nil
        }
    }

    func switchTo(_ call: BaresipCallID) async {
        guard let phone, let target = phone.call(call) else { return }
        do {
            try await phone.makeActive(target)
        } catch {
            append("switch failed: \(error)")
        }
    }

    func toggleHold(_ call: BaresipCallID) async {
        guard let target = phone?.call(call) else { return }
        do {
            try await target.setOnHold(!target.isOnHold)
        } catch {
            append("hold failed: \(error)")
        }
    }

    func hangup(_ call: BaresipCallID) async {
        try? await phone?.call(call)?.hangUp()
    }

    func showIncoming(_ call: BaresipCallID) async {
        guard phone?.call(call)?.isRinging == true else { return }
        shownIncoming = call
        incomingEarlyVideo = false
        previewing = false
        previewVideo = false
    }

    /// Records the finished call and, once no call is left, releases what the calls used.
    func callEnded(_ call: BaresipPhoneCall, remainingCalls: Int) async {
        recordHistory(call)
        dtmfStates[call.id] = nil
        answeredCalls.remove(call.id)
        if shownIncoming == call.id {
            shownIncoming = nil
        }
        if incoming == nil {
            previewing = false
            previewVideo = false
            incomingEarlyVideo = false
        }
        guard remainingCalls == 0 else { return }
        stats = nil
        callMinimized = false
        if previewAudioActive {
            previewAudioActive = false
            await audio?.deactivate()
        }
        if pendingApply {
            pendingApply = false
            Task { [weak self] in
                await self?.applySaved()
            }
        }
    }

    func reject() async {
        guard let incoming else { return }
        do {
            try await incoming.reject()
        } catch {
            append("decline failed: \(error)")
        }
        previewing = false
        previewVideo = false
    }

    func hangup() async {
        try? await activeCall?.hangUp()
    }

    /// Holds through CallKit on a device, so the system call screen shows the same state.

    func toggleHold() async {
        guard let currentCall else { return }
        await toggleHold(currentCall)
    }

    func normalizedDestination(_ raw: String) -> String {
        let value = raw.trimmed
        if value.isEmpty || value.hasPrefix("sip:") || value.hasPrefix("sips:") {
            return value
        }
        if value.contains("@") {
            return "sip:\(value)"
        }
        return "sip:\(value)@\((registeredSettings ?? settings).domain.trimmed)"
    }
}
