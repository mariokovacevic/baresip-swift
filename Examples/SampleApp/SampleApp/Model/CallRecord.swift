import Foundation

/// A finished call in the recent calls list.
struct CallRecord: Identifiable, Codable, Equatable {
    var id = UUID()
    let uri: String
    let name: String
    let outgoing: Bool
    let video: Bool
    let startedAt: Date
    /// How long the call was connected; `nil` when it never connected.
    let duration: TimeInterval?
    /// The DTMF digits the call was placed for, sent or not.
    let dtmf: String
    var dtmfResult: String?
    var dtmfAck: String?
    var dtmfHangUp: Bool
    /// A small picture of the caller's video, in `CallSnapshots`.
    var snapshotFile: String?
    /// Whether another phone answered (`answered`) or declined (`declined`) the ring; `nil` when
    /// the call ended here.
    var elsewhere: String?

    init(row: CallRow, endedAt: Date = Date(), snapshotFile: String? = nil) {
        self.snapshotFile = snapshotFile
        uri = row.uri
        name = row.remote == "…" ? CallRow.displayName(row.uri) : row.title
        outgoing = row.outgoing
        video = row.sendingVideo
        startedAt = row.startedAt
        duration = row.connectedAt.map { endedAt.timeIntervalSince($0) }
        dtmf = row.dtmfDigits
        dtmfResult = row.dtmf == nil ? nil : (row.dtmfSent ? row.dtmfResult : "not sent")
        dtmfAck = row.dtmf?.ack
        dtmfHangUp = row.dtmf?.hangUp ?? true
        switch row.endedElsewhere {
        case .answeredElsewhere: elsewhere = "answered"
        case .declinedElsewhere: elsewhere = "declined"
        case .replaced, nil: elsewhere = nil
        }
    }

    /// The same DTMF request again, when the call was placed to send DTMF.
    var dtmfRequest: DTMFRequest? {
        guard !dtmf.isEmpty else { return nil }
        return DTMFRequest(digits: dtmf, ack: dtmfAck ?? "", hangUp: dtmfHangUp)
    }

    /// What the call was, for repeating it: "Video call", "Audio call" or the DTMF request.
    var kindText: String {
        if let request = dtmfRequest {
            return "DTMF \(request.digits)" + (request.ack.isEmpty ? "" : ", reply \(request.ack)")
        }
        return video ? "Video call" : "Audio call"
    }

    var initials: String {
        CallRow.initials(name)
    }

    var statusText: String {
        let when = startedAt.formatted(date: .abbreviated, time: .shortened)
        guard let duration else {
            if let elsewhere {
                return "\(when) · \(elsewhere == "answered" ? "Answered" : "Declined") on another phone"
            }
            return "\(when) · \(outgoing ? "Not connected" : "Missed")"
        }
        let seconds = Int(duration.rounded())
        return "\(when) · \(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}
