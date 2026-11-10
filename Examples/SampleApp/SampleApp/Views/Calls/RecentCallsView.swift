import SwiftUI

struct RecentCallRow: View {
    @EnvironmentObject private var model: CallModel
    let record: CallRecord
    @State private var showOptions = false

    var body: some View {
        Button {
            showOptions = true
        } label: {
            HStack(spacing: 12) {
                if let file = record.snapshotFile, let image = CallSnapshots.image(named: file) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .accessibilityLabel("Picture from the call")
                } else {
                    Avatar(initials: record.initials,
                           tint: record.duration == nil ? Palette.destructive : Palette.secondaryText)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: record.outgoing ? "arrow.up.right" : "arrow.down.left")
                            .font(.caption)
                            .foregroundStyle(Palette.secondaryText)
                            .accessibilityLabel(record.outgoing ? "Outgoing" : "Incoming")
                        if record.video {
                            Image(systemName: "video.fill")
                                .font(.caption)
                                .foregroundStyle(Palette.secondaryText)
                                .accessibilityLabel("Video")
                        }
                        Text(record.name)
                            .font(.headline)
                            .foregroundStyle(record.duration == nil ? Palette.destructive : .primary)
                            .lineLimit(1)
                    }
                    Text(record.statusText + record.dtmfText)
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(Palette.secondaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows options to call again")
        .accessibilityIdentifier("recents.row")
        .confirmationDialog(record.name, isPresented: $showOptions, titleVisibility: .visible) {
            Button("Repeat: \(record.kindText)") {
                Task { await model.repeatCall(record, as: .same) }
            }
            if record.dtmfRequest != nil || record.video {
                Button("Audio call") { Task { await model.repeatCall(record, as: .audio) } }
            }
            if record.dtmfRequest != nil || !record.video {
                Button("Video call") { Task { await model.repeatCall(record, as: .video) } }
            }
            Button("Edit address") { model.redial(record) }
        } message: {
            Text(record.uri)
        }
    }
}

struct RecentCallsView: View {
    @EnvironmentObject private var model: CallModel
    @State private var confirmClear = false

    var body: some View {
        List {
            ForEach(model.history) { record in
                RecentCallRow(record: record)
            }
            .onDelete { model.history.remove(atOffsets: $0) }
        }
        .navigationTitle("Recent calls")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear", role: .destructive) { confirmClear = true }
                    .disabled(model.history.isEmpty)
            }
        }
        .confirmationDialog("Clear all recent calls?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear", role: .destructive) { model.history.removeAll() }
        }
    }
}
