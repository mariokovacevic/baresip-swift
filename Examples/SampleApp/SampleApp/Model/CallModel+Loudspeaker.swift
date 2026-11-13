import UIKit
import BaresipKit
import BaresipKitAudio

/// Calls play on the loudspeaker, as an intercom is held away from the face to see the door.
/// Held to the ear, the proximity sensor moves the audio to the earpiece, and back when the
/// phone moves away. Once the user picks an output in a call, that call keeps it. A headset or
/// car kit is never switched away from.
extension CallModel {
    /// Puts a call on the loudspeaker when its media first runs, and starts watching the
    /// proximity sensor. CallKit starts audio calls on the earpiece despite the session's
    /// default.
    func startOnLoudspeaker(_ call: BaresipCallID) {
        watchProximity()
        guard loudspeakerCalls.insert(call).inserted, !manualOutputCalls.contains(call) else { return }
        route(toSpeaker: !UIDevice.current.proximityState)
    }

    /// The user chose an output for the current call.
    func userChoseOutput() {
        if let currentCall {
            manualOutputCalls.insert(currentCall)
        }
    }

    func callEnded(_ call: BaresipCallID) {
        loudspeakerCalls.remove(call)
        manualOutputCalls.remove(call)
        if (phone?.calls ?? []).allSatisfy({ $0.id == call }) {
            stopWatchingProximity()
        }
    }

    private func watchProximity() {
        guard proximityObserver == nil else { return }
        UIDevice.current.isProximityMonitoringEnabled = true
        proximityObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.proximityStateDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.proximityChanged()
            }
        }
    }

    private func stopWatchingProximity() {
        if let proximityObserver {
            NotificationCenter.default.removeObserver(proximityObserver)
        }
        proximityObserver = nil
        UIDevice.current.isProximityMonitoringEnabled = false
    }

    private func proximityChanged() {
        guard let currentCall, !manualOutputCalls.contains(currentCall) else { return }
        route(toSpeaker: !UIDevice.current.proximityState)
    }

    /// Switches between the loudspeaker and the earpiece, never away from a headset.
    private func route(toSpeaker: Bool) {
        guard let audio, audio.currentRoute == .speaker || audio.currentRoute == .earpiece,
              (audio.currentRoute == .speaker) != toSpeaker else { return }
        do {
            try audio.setSpeakerEnabled(toSpeaker)
            audioRouteChanges += 1
        } catch {
            append("audio output change failed: \(error)")
        }
    }
}
