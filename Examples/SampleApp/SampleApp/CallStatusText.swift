import Foundation
import BaresipKit

func formatDuration(since start: Date?, now: Date) -> String {
    guard let start else { return "00:00" }
    let seconds = max(0, Int(now.timeIntervalSince(start)))
    let h = seconds / 3600
    let m = (seconds % 3600) / 60
    let s = seconds % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
}

func callStatusText(_ row: CallRow, now: Date) -> String {
    switch row.state {
    case .incoming: return "Incoming"
    case .outgoingInit: return "Calling…"
    case .outgoingRinging: return "Ringing…"
    case .earlyMedia: return "Connecting…"
    case .connected, .streamsRunning, .updating, .resuming: return formatDuration(since: row.connectedAt, now: now)
    case .pausing, .paused: return "On hold · " + formatDuration(since: row.connectedAt, now: now)
    case .pausedByRemote: return "Held by the other side"
    case .ended, .failed, .released: return "Ended"
    }
}
