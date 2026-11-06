import SwiftUI
import BaresipKit

struct CallListRow: View {
    @EnvironmentObject private var model: CallModel
    let row: CallRow

    var body: some View {
        HStack(spacing: 12) {
            Avatar(initials: row.initials,
                   tint: isCurrent ? Palette.green : Palette.secondaryText,
                   background: isCurrent ? Color(red: 0.89, green: 0.94, blue: 0.9) : Color(.systemGray6))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: row.outgoing ? "arrow.up.right" : "arrow.down.left")
                        .font(.caption)
                        .foregroundStyle(Palette.secondaryText)
                        .accessibilityLabel(row.outgoing ? "Outgoing" : "Incoming")
                    Text(row.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text((isCurrent ? "Current · " : "") + callStatusText(row, now: context.date) +
                        (row.codec.isEmpty ? "" : " · \(row.codec)"))
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(isCurrent ? Palette.green : Palette.secondaryText)
                }
            }
            Spacer(minLength: 8)
            if row.state == .incoming {
                Button("Open") { Task { await model.showIncoming(row.id) } }
                    .buttonStyle(.bordered)
            } else if !isCurrent {
                Button("Switch") { Task { await model.switchTo(row.id) } }
                    .buttonStyle(.bordered)
                    .tint(Palette.blue)
            } else {
                Button(row.isHeld ? "Resume" : "Hold") { Task { await model.toggleHold(row.id) } }
                    .buttonStyle(.bordered)
                    .tint(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contextMenu {
            Button("Hang up", role: .destructive) { Task { await model.hangup(row.id) } }
        }
        .accessibilityIdentifier("calls.row")
    }

    private var isCurrent: Bool {
        row.id == model.currentCall
    }
}
