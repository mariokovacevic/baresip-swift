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
            incoming = info
            incomingEarlyVideo = earlyVideo
            if let index = calls.firstIndex(where: { $0.id == info.id }) {
                calls[index].remote = info.remoteDisplayName.isEmpty ? info.remoteURI : info.remoteDisplayName
            } else {
                calls.append(CallRow(id: info.id,
                                     remote: info.remoteDisplayName.isEmpty ? info.remoteURI : info.remoteDisplayName,
                                     state: .incoming, outgoing: false))
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
        case .call(let call, let state, let error):
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
        case .message(let message):
            messages.append(ChatMessage(id: UUID(), messageID: nil, peer: message.from,
                                        text: message.text ?? "<\(message.contentType), \(message.body.count) bytes>",
                                        outgoing: false, status: .received))
            append("message from \(message.from)")
        case .messageStatus(let status):
            let result: ChatMessage.Status = status.delivered ? .delivered
                : .failed(status.error.map { "\($0)" } ?? "\(status.sipStatus ?? 0)")
            if let index = messages.lastIndex(where: { $0.messageID == status.id }) {
                messages[index].status = result
            } else {
                earlyStatuses[status.id] = result
            }
        case .media(let call, let info):
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
        case .transfer(let call, let event):
            append("transfer \(call): \(event.failed ? "failed" : "requested") \(event.targetURI)")
        case .statistics(_, let s):
            stats = s
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
}
