import SwiftUI

struct ActivityRow: View {
    @EnvironmentObject private var model: CallModel
    let entry: ActivityEntry
    @State private var showOptions = false

    var body: some View {
        HStack(spacing: 12) {
            Button {
                showOptions = true
            } label: {
                HStack(spacing: 12) {
                    thumbnail
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(entry.kind == .missed ? Theme.alert : Theme.text)
                            .lineLimit(1)
                        Text(entry.subtitle)
                            .font(.footnote)
                            .foregroundStyle(Theme.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows options to call again")
            .accessibilityIdentifier("recents.row")
            repeatButton
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .padding(.vertical, 10)
        .confirmationDialog(entry.record.name, isPresented: $showOptions, titleVisibility: .visible) {
            Button("Repeat: \(entry.record.kindText)") {
                Task { await model.repeatCall(entry.record, as: .same) }
            }
            if entry.record.dtmfRequest != nil || entry.record.video {
                Button("Audio call") { Task { await model.repeatCall(entry.record, as: .audio) } }
            }
            if entry.record.dtmfRequest != nil || !entry.record.video {
                Button("Video call") { Task { await model.repeatCall(entry.record, as: .video) } }
            }
            Button("Edit address") {
                model.redial(entry.record)
                model.tab = .keypad
            }
            Button("Remove from Activity", role: .destructive) {
                model.history.removeAll { $0.id == entry.record.id }
            }
        } message: {
            Text(entry.record.uri)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        if let file = entry.record.snapshotFile, let image = CallSnapshots.image(named: file) {
            CameraPicture(image: image)
                .frame(width: 60, height: 46)
                .clipShape(shape)
                .overlay(shape.stroke(Theme.field))
        } else if entry.kind == .opened {
            Image(systemName: "key")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.brass)
                .frame(width: 60, height: 46)
                .background(Theme.brassSoft, in: shape)
                .overlay(shape.stroke(Theme.brassLine))
                .accessibilityHidden(true)
        } else if entry.door != nil {
            CameraPicture(image: nil, markSize: 24)
                .frame(width: 60, height: 46)
                .clipShape(shape)
                .overlay(shape.stroke(Theme.field))
                .accessibilityHidden(true)
        } else {
            Avatar(initials: entry.record.initials, size: 46, corner: 10)
                .frame(width: 60, height: 46)
        }
    }

    private var repeatButton: some View {
        Button {
            Task {
                if entry.kind == .opened, let door = entry.door {
                    await model.open(door)
                } else {
                    await model.repeatCall(entry.record, as: .same)
                }
            }
        } label: {
            Image(systemName: repeatIcon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(entry.kind == .opened ? Theme.brass : Theme.info)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.kind == .opened ? "Open again" : "Call again")
    }

    private var repeatIcon: String {
        if entry.kind == .opened {
            return "key"
        }
        return entry.record.video ? "video" : "phone"
    }
}
