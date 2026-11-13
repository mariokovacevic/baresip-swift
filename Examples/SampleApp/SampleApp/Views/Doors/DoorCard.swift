import SwiftUI

/// A saved door in one row: a small last picture that calls the door, its name and last ring,
/// and the Open button.
struct DoorCard: View {
    @EnvironmentObject private var model: CallModel
    let door: Door

    var body: some View {
        Card {
            HStack(spacing: 12) {
                if door.hasCamera {
                    thumbnail
                }
                NavigationLink {
                    DoorView(door: door)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(door.title)
                            .font(.display(22))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                        subtitle
                    }
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if door.canOpen {
                    Button {
                        Task { await model.open(door) }
                    } label: {
                        Label("Open", systemImage: "key")
                    }
                    .buttonStyle(FilledButtonStyle(kind: .brass, height: 48, expands: false))
                    .accessibilityLabel("Open \(door.title)")
                    .accessibilityIdentifier("door.open")
                } else {
                    Button {
                        Task { await model.look(at: door) }
                    } label: {
                        Label("Call", systemImage: "phone")
                    }
                    .buttonStyle(FilledButtonStyle(kind: .raised, height: 48, expands: false))
                }
            }
            .padding(.leading, door.hasCamera ? 12 : 16)
            .padding(.trailing, 14)
            .padding(.vertical, 12)
        }
    }

    /// The last picture the door's camera sent, small, so it does not pass for a live view; a
    /// touch calls the door to see it now.
    private var thumbnail: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return Button {
            Task { await model.look(at: door) }
        } label: {
            CameraPicture(image: picture, markSize: 26)
                .frame(width: 64, height: 64)
                .clipShape(shape)
                .overlay(shape.stroke(Theme.line))
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .padding(5)
                        .background(Theme.bar, in: Circle())
                        .padding(4)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Look at \(door.title)")
        .accessibilityIdentifier("door.look")
    }

    @ViewBuilder
    private var subtitle: some View {
        if let record = model.lastRecord(of: door) {
            Text(ringText(record))
                .font(.footnote)
                .foregroundStyle(record.duration == nil && !record.outgoing ? Theme.alert : Theme.secondary)
                .lineLimit(1)
        } else {
            Text(detail)
                .font(.footnote)
                .foregroundStyle(Theme.secondary)
                .lineLimit(1)
        }
    }

    private var detail: String {
        let kind = door.hasCamera ? "With camera" : "Audio only"
        return door.canOpen ? kind : "\(kind), no code set"
    }

    private var picture: UIImage? {
        for record in model.history where record.user == door.user {
            if let file = record.snapshotFile, let image = CallSnapshots.image(named: file) {
                return image
            }
        }
        return nil
    }

    private func ringText(_ record: CallRecord) -> String {
        let time = record.startedAt.formatted(date: .omitted, time: .shortened)
        if record.outgoing {
            return record.dtmf.isEmpty ? "Called \(time)" : "Opened \(time)"
        }
        return record.duration == nil ? "Rang \(time), missed" : "Rang \(time), answered"
    }
}
