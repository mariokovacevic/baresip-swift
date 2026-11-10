import Foundation
import BaresipKit

extension CallModel {
    func toggleRecording() async {
        guard let engine, let currentCall else { return }
        do {
            if recordingCall == currentCall {
                try await engine.stopRecording(callID: currentCall)
            } else {
                let folder = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
                                                         appropriateFor: nil, create: true)
                    .appendingPathComponent("Recordings", isDirectory: true)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
                let name = CallRow.displayName(currentRow?.remote ?? "call")
                    .replacingOccurrences(of: "/", with: "-")
                let url = folder.appendingPathComponent("\(stamp) \(name).wav")
                let previous = lastRecording
                lastRecording = url
                do {
                    try await engine.startRecording(callID: currentCall, to: url)
                } catch {
                    lastRecording = previous
                    throw error
                }
            }
        } catch {
            append("recording failed: \(error)")
        }
    }
}
