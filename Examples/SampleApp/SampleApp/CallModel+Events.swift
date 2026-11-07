import Foundation
import BaresipKit

extension CallModel {
    func handle(_ event: BaresipEvent) async {
        switch event {
        case .engine(let state, let error):
            append("engine \(state) \(error.map { "\($0)" } ?? "")")
        case .registration(_, let state, _, let error):
            registration = state
            registrationError = error.map { "\($0)" }
            append("registration \(state) \(error.map { "\($0)" } ?? "")")
        case .incomingCall(let info, let earlyVideo):
            await handleIncoming(info, earlyVideo: earlyVideo)
        case .call(let call, let state, let error):
            await handleState(state, of: call, error: error)
        case .message(let message):
            handleMessage(message)
        case .messageStatus(let status):
            handleMessageStatus(status)
        case .media(let call, let info):
            handleMedia(info, of: call)
        case .transfer(let call, let event):
            append("transfer \(call): \(event.failed ? "failed" : "requested") \(event.targetURI)")
        case .statistics(_, let statistics):
            stats = statistics
        case .ice(_, let ice):
            append("ice \(ice.state) \(ice.localCandidate)/\(ice.remoteCandidate) \(ice.remoteAddress)")
        case .dtmf(_, let dtmf):
            if !dtmf.isEnd {
                append("dtmf \(dtmf.digit)")
            }
        default:
            break
        }
    }

    private func handleIncoming(_ info: BaresipCallInfo, earlyVideo: Bool) async {
        incoming = info
        incomingEarlyVideo = earlyVideo
        let remote = info.remoteDisplayName.isEmpty ? info.remoteURI : info.remoteDisplayName
        if let index = calls.firstIndex(where: { $0.id == info.id }) {
            calls[index].remote = remote
        } else {
            calls.append(CallRow(id: info.id, remote: remote, state: .incoming, outgoing: false))
        }
        if currentCall == nil {
            currentCall = info.id
        }
        if registeredSettings?.autoPreview == true, !calls.contains(where: { $0.id != info.id }) {
            previewing = true
            previewVideo = info.hasVideo || earlyVideo
            await activatePreviewAudio()
        }
        append("incoming call from \(info.remoteURI)\(earlyVideo ? " (early video offered)" : "")")
    }

    private func handleState(_ state: BaresipCallState, of call: BaresipCallID, error: BaresipError?) async {
        append("call \(call) \(state) \(error.map { "\($0)" } ?? "")")
        updateRow(call, state: state)
        if state == .outgoingInit, currentCall == nil || heldCall != nil || currentCallOnHold {
            currentCall = call
        }
        if call == currentCall {
            callState = state
            onHold = state == .paused || state == .pausing
        }
        if state == .released {
            await callReleased(call)
        }
    }

    private func handleMessage(_ message: BaresipMessage) {
        let text = message.text ?? "<\(message.contentType), \(message.body.count) bytes>"
        messages.append(ChatMessage(id: UUID(), messageID: nil, peer: message.from,
                                    text: text, outgoing: false, status: .received))
        append("message from \(message.from)")
    }

    private func handleMessageStatus(_ status: BaresipMessageStatus) {
        let result: ChatMessage.Status = status.delivered
            ? .delivered
            : .failed(status.error.map { "\($0)" } ?? "\(status.sipStatus ?? 0)")
        if let index = messages.lastIndex(where: { $0.messageID == status.id }) {
            messages[index].status = result
        } else {
            earlyStatuses[status.id] = result
        }
    }

    private func handleMedia(_ info: BaresipMediaEventInfo, of call: BaresipCallID) {
        switch info.event {
        case .recordingStarted:
            recordingCall = call
            append("recording \(call) to \(lastRecording?.lastPathComponent ?? "file")")
        case .recordingStopped:
            if recordingCall == call {
                recordingCall = nil
            }
            append("recording of \(call) saved")
        default:
            break
        }
    }
}
