import Foundation
import BaresipKit
import BaresipKitAudio

extension CallModel {
    /// Mutes through CallKit on a device, so the system call screen shows the same state.
    func toggleMute() async {
        guard let activeCall else { return }
        do {
            try await activeCall.setMuted(!activeCall.isMuted)
        } catch {
            append("mute failed: \(error)")
        }
    }

    /// Turns our camera on or off. Only sending changes: the other side's video, such as a
    /// door station's camera, keeps playing.
    func toggleVideo() async {
        guard let activeCall else { return }
        do {
            try await activeCall.setVideoEnabled(!activeCall.isSendingVideo)
        } catch {
            append("camera change failed: \(error)")
        }
    }

    func switchCamera() async {
        do {
            try await activeCall?.switchCamera()
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

    func selectOutput(_ output: BaresipAudioOutput) {
        do {
            try audio?.selectOutput(output)
            append("audio output: \(output.name)")
        } catch {
            append("audio output \(output.name) failed: \(error)")
        }
        audioRouteChanges += 1
    }
}
