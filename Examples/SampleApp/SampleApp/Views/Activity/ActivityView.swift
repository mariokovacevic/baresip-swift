import SwiftUI

struct ActivityView: View {
    @EnvironmentObject private var model: CallModel
    @State private var filter = ActivityEntry.Filter.all
    @State private var confirmClear = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenTitle(title: "Activity")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ActivityEntry.Filter.allCases, id: \.self) { choice in
                            FilterChip(title: choice.title, selected: filter == choice) { filter = choice }
                        }
                    }
                }
                if days.isEmpty {
                    Note(text: model.history.isEmpty ? "Rings, calls and opened doors appear here." : "Nothing here.")
                        .padding(.top, 8)
                }
                ForEach(days, id: \.title) { day in
                    TitledSection(title: day.title) {
                        Card {
                            ForEach(Array(day.entries.enumerated()), id: \.element.id) { index, entry in
                                if index > 0 {
                                    RowDivider()
                                }
                                ActivityRow(entry: entry)
                            }
                        }
                    }
                }
                if !model.history.isEmpty {
                    Note(text: """
                    The button on the right repeats the call or the opening. Pictures stay on this phone with \
                    the last \(SettingsStore.historyLimit) entries.
                    """)
                }
            }
            .padding(16)
        }
        .titledScreen("Activity")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear", role: .destructive) { confirmClear = true }
                    .disabled(model.history.isEmpty)
            }
        }
        .confirmationDialog("Clear all activity?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear", role: .destructive) { model.history.removeAll() }
        }
    }

    private var days: [(title: String, entries: [ActivityEntry])] {
        var result: [(title: String, entries: [ActivityEntry])] = []
        for entry in model.activity where filter.includes(entry.kind) {
            if let last = result.indices.last, result[last].title == entry.day {
                result[last].entries.append(entry)
            } else {
                result.append((title: entry.day, entries: [entry]))
            }
        }
        return result
    }
}
