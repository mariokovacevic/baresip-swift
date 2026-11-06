import Foundation
import BaresipKit

func formatDuration(since start: Date?, now: Date) -> String {
    guard let start else { return "00:00" }
    let seconds = max(0, Int(now.timeIntervalSince(start)))
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let rest = seconds % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, rest)
    }
    return String(format: "%02d:%02d", minutes, rest)
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
