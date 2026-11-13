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
            if state == .registered, let pendingRedial {
                await redial(pendingRedial)
            }
        case .incomingCall(let info, let earlyVideo):
            await handleIncoming(info, earlyVideo: earlyVideo)
        case .call(let call, let state, let error):
            await handleState(state, of: call, error: error)
        case .message(let message):
            receive(message)
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
                append("dtmf \(dtmf.digit)\(dtmf.viaSIPInfo ? " (SIP INFO)" : "")")
            }
        default:
            break
        }
    }

    private func handleIncoming(_ info: BaresipCallInfo, earlyVideo: Bool) async {
        ringingCalls.insert(info.id)
        incomingEarlyVideo = earlyVideo
        append("incoming call from \(info.remoteURI)\(earlyVideo ? " (early video offered)" : "")")
        if let settings = registeredSettings, phone?.calls.contains(where: { $0.id != info.id }) != true {
            logPreview(info.id, audio: settings.previewAudio, video: earlyVideo)
            if settings.previewAudio {
                // The account answers early media itself.
                if earlyVideo {
                    await startPreviewFeed(info.id)
                }
                previewing = true
                previewVideo = earlyVideo
                await activatePreviewAudio()
            } else {
                // Only video the caller sends can be previewed; an offer to receive video has none.
                await preview(info.id, hasVideo: earlyVideo)
            }
        }
    }

    /// Says what the automatic preview of an incoming call receives. With CallKit, iOS turns the
    /// audio on only once the call is answered, so the caller is heard from then on.
    private func logPreview(_ call: BaresipCallID, audio: Bool, video: Bool) {
        let receivesAudio = audio || !video
        let media = receivesAudio ? (video ? "audio+video" : "audio") : "video only"
        let note = receivesAudio && !usesDirectCalls ? " (audio heard after answering)" : ""
        append("preview \(call): \(media)\(note)")
    }

    private func handleState(_ state: BaresipCallState, of call: BaresipCallID, error: BaresipError?) async {
        append("call \(call) \(state) \(error.map { "\($0)" } ?? "")")
        // Answered here or on the system call screen. Tracked from this model's own events, as
        // `BaresipPhone` may not have added the call yet.
        if state == .connected || state == .streamsRunning, ringingCalls.remove(call) != nil {
            didAnswer(call)
        }
        if state == .released {
            ringingCalls.remove(call)
            callEnded(call)
        }
        if state == .streamsRunning {
            startOnLoudspeaker(call)
            sendQueuedDTMF(call)
        }
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
