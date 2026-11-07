import Foundation
import BaresipKit

extension CallModel {
    func call(video: Bool) async {
        let target = normalizedDestination(destination)
        guard !target.isEmpty else { return }
        if uiTest, let engine {
            callMinimized = false
            pendingOutgoingVideo = video
            do {
                let call = try await engine.makeCall(accountID: accountID, destination: target, video: video)
                setVideo(video, for: call)
            } catch {
                append("call failed: \(error)")
            }
            return
        }
        callMinimized = false
        guard let callKit else { return }
        pendingOutgoingVideo = video
        do {
            _ = try await callKit.startOutgoingCall(to: target, video: video)
        } catch {
            append("call failed: \(error)")
        }
    }

    func preview() async {
        guard let engine, let incoming, !previewing else { return }
        let video = incoming.hasVideo || incomingEarlyVideo
        do {
            await activatePreviewAudio()
            try await engine.sendProgress(callID: incoming.id, earlyVideo: video)
            previewing = true
            previewVideo = video
            append("previewing \(incoming.remoteURI) (they do not hear or see you)")
        } catch {
            append("preview failed: \(error)")
        }
    }

    func activatePreviewAudio() async {
        guard !previewAudioActive, let audio else { return }
        do {
            try await audio.activate()
            previewAudioActive = true
        } catch {
            append("audio for preview unavailable: \(error)")
        }
    }

    func answer() async {
        guard let engine, let incoming else { return }
        let others = calls.contains { $0.id != incoming.id }
        try? await engine.answer(callID: incoming.id, video: incoming.hasVideo)
        if others {
            try? await engine.setActiveCall(incoming.id)
        }
        currentCall = incoming.id
        callState = calls.first { $0.id == incoming.id }?.state
        onHold = false
        callMinimized = false
        setVideo(incoming.hasVideo, for: incoming.id)
        previewing = false
        previewVideo = false
        self.incoming = nil
    }

    func switchTo(_ call: BaresipCallID) async {
        guard let engine else { return }
        do {
            try await engine.setActiveCall(call)
            if call == heldCall {
                heldCall = currentCall
            }
            currentCall = call
            callState = calls.first { $0.id == call }?.state
            onHold = false
        } catch {
            append("switch failed: \(error)")
        }
    }

    func toggleHold(_ call: BaresipCallID) async {
        guard let engine, let row = calls.first(where: { $0.id == call }) else { return }
        let held = row.state == .paused || row.state == .pausing
        if held {
            try? await engine.resume(callID: call)
        } else {
            try? await engine.hold(callID: call)
        }
        if call == currentCall {
            onHold = !held
        }
    }

    func hangup(_ call: BaresipCallID) async {
        try? await engine?.hangup(callID: call)
    }

    var currentCallOnHold: Bool {
        guard let currentCall, let row = calls.first(where: { $0.id == currentCall }) else { return false }
        return row.state == .paused || row.state == .pausing
    }

    func updateRow(_ call: BaresipCallID, state: BaresipCallState) {
        if let index = calls.firstIndex(where: { $0.id == call }) {
            calls[index].state = state
            if calls[index].connectedAt == nil, state == .connected || state == .streamsRunning {
                calls[index].connectedAt = Date()
                refreshInfo(call)
            }
            return
        }
        guard state != .released else { return }
        let outgoing = state != .incoming
        calls.append(CallRow(id: call, remote: "…", state: state, outgoing: outgoing,
                             hasVideo: outgoing && pendingOutgoingVideo))
        if outgoing {
            pendingOutgoingVideo = false
        }
        refreshInfo(call)
    }

    func refreshInfo(_ call: BaresipCallID) {
        Task { [weak self] in
            guard let self, let engine,
                  let info = try? await engine.callInfo(callID: call) else { return }
            if let index = calls.firstIndex(where: { $0.id == call }) {
                calls[index].remote = info.remoteDisplayName.isEmpty ? info.remoteURI : info.remoteDisplayName
                calls[index].outgoing = info.isOutgoing
                calls[index].codec = info.audioCodec
                calls[index].hasVideo = info.hasVideo
            }
        }
    }

    var videoEnabled: Bool {
        currentRow?.hasVideo ?? false
    }

    func setVideo(_ enabled: Bool, for call: BaresipCallID) {
        guard let index = calls.firstIndex(where: { $0.id == call }) else { return }
        calls[index].hasVideo = enabled
    }

    var currentRow: CallRow? {
        calls.first { $0.id == currentCall }
    }

    var heldRow: CallRow? {
        calls.first { $0.id == heldCall }
    }

    func showIncoming(_ call: BaresipCallID) async {
        guard incoming?.id != call, let engine,
              let info = try? await engine.callInfo(callID: call) else { return }
        incoming = info
        incomingEarlyVideo = false
        previewing = false
        previewVideo = false
    }

    func callReleased(_ call: BaresipCallID) async {
        calls.removeAll { $0.id == call }
        if heldCall == call {
            heldCall = nil
        }
        if incoming?.id == call {
            incoming = nil
            previewing = false
            previewVideo = false
        }
        guard call == currentCall else { return }
        if let next = heldCall ?? calls.first?.id {
            heldCall = nil
            currentCall = next
            callState = calls.first { $0.id == next }?.state
            if let engine {
                try? await engine.resume(callID: next)
            }
            onHold = false
            return
        }
        currentCall = nil
        callState = nil
        stats = nil
        onHold = false
        muted = false
        previewing = false
        previewVideo = false
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
        guard let engine, let incoming else { return }
        try? await engine.reject(callID: incoming.id, statusCode: 486)
        previewing = false
        previewVideo = false
        self.incoming = nil
    }

    func hangup() async {
        guard let engine, let currentCall else { return }
        try? await engine.hangup(callID: currentCall)
    }

    func toggleHold() async {
        guard let engine, let currentCall else { return }
        if onHold {
            try? await engine.resume(callID: currentCall)
        } else {
            try? await engine.hold(callID: currentCall)
        }
        onHold.toggle()
    }

    func toggleMute() async {
        guard let engine, let currentCall else { return }
        muted.toggle()
        try? await engine.setMicrophoneMuted(muted, callID: currentCall)
    }

    func toggleVideo() async {
        guard let engine, let currentCall else { return }
        let enabled = !videoEnabled
        setVideo(enabled, for: currentCall)
        try? await engine.setVideoEnabled(enabled, callID: currentCall)
    }

    func sendDTMF(_ digits: String) async {
        guard let engine, let currentCall else { return }
        try? await engine.sendDTMF(callID: currentCall, digits: digits)
    }

    func switchCamera() async {
        guard let engine, let currentCall else { return }
        frontCamera.toggle()
        do {
            try await engine.setCamera(frontCamera ? "front" : "back", callID: currentCall)
        } catch {
            append("camera switch failed: \(error)")
        }
    }

    func restartICE() async {
        guard let engine, let currentCall else { return }
        do {
            try await engine.restartICE(callID: currentCall)
        } catch {
            append("ICE restart failed: \(error)")
        }
    }

    func toggleSpeaker(_ on: Bool) {
        try? audio?.setSpeakerEnabled(on)
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
