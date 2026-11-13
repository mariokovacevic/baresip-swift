import Foundation

/// A finished call as the Activity list shows it: a missed ring, an opened door, a talk with a
/// door, or an ordinary call.
struct ActivityEntry: Identifiable {
    enum Kind {
        case missed
        case elsewhere
        case opened
        case door
        case call
        case notConnected
    }

    enum Filter: CaseIterable {
        case all
        case missed
        case opened
        case calls

        var title: String {
            switch self {
            case .all: return "All"
            case .missed: return "Missed"
            case .opened: return "Opened"
            case .calls: return "Calls"
            }
        }

        func includes(_ kind: Kind) -> Bool {
            switch self {
            case .all: return true
            case .missed: return kind == .missed
            case .opened: return kind == .opened
            case .calls: return kind == .call || kind == .notConnected || kind == .elsewhere
            }
        }
    }

    let record: CallRecord
    let door: Door?

    var id: UUID {
        record.id
    }

    var kind: Kind {
        if !record.dtmf.isEmpty, let result = record.dtmfResult, result == "sent" || result == "door opened" {
            return .opened
        }
        if record.duration == nil {
            if record.elsewhere != nil {
                return .elsewhere
            }
            return record.outgoing ? .notConnected : .missed
        }
        return door == nil ? .call : .door
    }

    var title: String {
        switch kind {
        case .missed: return door == nil ? "Missed call" : "Missed ring"
        case .elsewhere:
            return record.elsewhere == "declined" ? "Declined on another phone" : "Answered on another phone"
        case .opened: return record.outgoing ? "You opened the door" : "Answered, door opened"
        case .door: return record.outgoing ? "You looked at the door" : "Answered"
        case .notConnected: return "Not connected"
        case .call:
            let call = record.video ? "Video call" : "Call"
            return "\(call) \(record.outgoing ? "to" : "from") \(record.name)"
        }
    }

    var subtitle: String {
        var parts = [door?.title ?? (kind == .call ? CallRow.displayName(record.uri) : record.name)]
        parts.append(record.startedAt.formatted(date: .omitted, time: .shortened))
        if let duration = record.duration {
            let seconds = Int(duration.rounded())
            parts.append("talked \(seconds / 60):\(String(format: "%02d", seconds % 60))")
        }
        if !record.dtmf.isEmpty, kind != .opened {
            parts.append("code \(record.dtmfResult ?? "not sent")")
        }
        return parts.joined(separator: ", ")
    }

    /// The day heading the entry is listed under.
    var day: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(record.startedAt) {
            return "Today"
        }
        if calendar.isDateInYesterday(record.startedAt) {
            return "Yesterday"
        }
        return record.startedAt.formatted(date: .abbreviated, time: .omitted)
    }
}

extension CallRecord {
    /// The SIP user of the other side.
    var user: String {
        CallRow.displayName(uri.isEmpty ? name : uri)
    }
}

extension CallModel {
    var activity: [ActivityEntry] {
        history.map { ActivityEntry(record: $0, door: door(for: $0.user)) }
    }
}
