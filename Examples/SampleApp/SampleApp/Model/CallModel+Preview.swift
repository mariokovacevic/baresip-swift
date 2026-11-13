import Foundation
import BaresipKit
import BaresipKitAudio

extension CallModel {
    func preview() async {
        guard let incoming else { return }
        await preview(incoming.id, hasVideo: incomingEarlyVideo)
    }

    /// Hears and sees the caller before answering; they do not hear or see you.
    ///
    /// Takes the call's identifier because the incoming call event can reach this model before
    /// `BaresipPhone` has added the call.
    func preview(_ call: BaresipCallID, hasVideo: Bool) async {
        guard !previewing, let engine else { return }
        let audio = (registeredSettings?.previewAudio ?? true) || !hasVideo
        do {
            if audio {
                await activatePreviewAudio()
            }
            if let tracked = phone?.call(call) {
                try await tracked.startPreview(video: hasVideo, audio: audio)
            } else {
                try await engine.sendProgress(callID: call, earlyVideo: hasVideo, earlyAudio: audio)
            }
            if hasVideo {
                await startPreviewFeed(call)
            }
            previewing = true
            previewVideo = hasVideo
            append("previewing \(call) (they do not hear or see you)")
        } catch {
            append("preview failed: \(error)")
        }
    }

    /// Activates the audio session to hear an early media preview. Only without CallKit: with
    /// CallKit, iOS lets only CallKit activate it, once the call is answered.

    func activatePreviewAudio() async {
        guard usesDirectCalls, !previewAudioActive, let audio else { return }
        do {
            try await audio.activate()
            previewAudioActive = true
        } catch {
            append("audio for preview unavailable: \(error)")
        }
    }
}
