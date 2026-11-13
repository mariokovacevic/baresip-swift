import SwiftUI
import BaresipKit

struct DoorsView: View {
    @EnvironmentObject private var model: CallModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenTitle(title: "Doors")
                if model.callOnScreen != nil, model.callMinimized {
                    ReturnToCallBar()
                }
                ReachabilityLine()
                if model.doors.isEmpty {
                    addFirstDoor
                }
                ForEach(model.doors) { door in
                    DoorCard(door: door)
                }
                todaySection
            }
            .padding(16)
        }
        .titledScreen("Doors")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    DoorView(door: Door())
                } label: {
                    RoundIcon(systemImage: "plus", size: 36)
                }
                .accessibilityLabel("Add a door")
            }
        }
    }

    private var addFirstDoor: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Add your door")
                    .font(.display(22))
                    .foregroundStyle(Theme.text)
                Text("""
                Enter the door station's SIP user and the code that opens it. Rings from it then show \
                its picture and an Open button.
                """)
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
                NavigationLink {
                    DoorView(door: Door())
                } label: {
                    Label("Add a door", systemImage: "plus")
                }
                .buttonStyle(FilledButtonStyle(kind: .brass, height: 48))
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var todaySection: some View {
        let today = model.activity.prefix(while: { $0.day == "Today" }).prefix(3)
        if !today.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    SectionTitle(title: "Today")
                    Spacer()
                    Button("See all") { model.tab = .activity }
                        .font(.subheadline.weight(.medium))
                        .frame(minHeight: 44)
                }
                Card {
                    ForEach(Array(today.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 {
                            RowDivider()
                        }
                        ActivityRow(entry: entry)
                    }
                }
            }
        }
    }
}

/// Whether rings reach the phone: registered, and kept registered in the background or not.
struct ReachabilityLine: View {
    @EnvironmentObject private var model: CallModel

    var body: some View {
        HStack(spacing: 8) {
            StatusDot(color: color)
            Text(text)
                .font(.footnote)
                .foregroundStyle(Theme.secondary)
                .lineLimit(2)
        }
        .accessibilityElement(children: .combine)
    }

    private var text: String {
        switch model.registration {
        case .registered:
            return model.settings.reachableInBackground
                ? "Reachable. Rings arrive even when the app is closed."
                : "Reachable while Zvono is open. Turn on push in Settings to get rings when it is closed."
        case .registering: return "Connecting to \(model.settings.domain.trimmed)…"
        case .unregistering: return "Signing out…"
        case .failed: return "Not connected\(model.registrationError.map { ": \($0)" } ?? "")"
        case .none: return model.registrationError ?? "Offline"
        }
    }

    private var color: Color {
        switch model.registration {
        case .registered: return Theme.info
        case .failed: return Theme.alert
        case .registering, .unregistering: return Theme.brass
        case .none: return Theme.secondary
        }
    }
}

/// Leads back to the call the user left with the chevron, or to the list when there are more.
struct ReturnToCallBar: View {
    @EnvironmentObject private var model: CallModel

    var body: some View {
        if model.calls.count > 1 {
            NavigationLink {
                CallsView()
            } label: {
                label
            }
            .buttonStyle(.plain)
        } else {
            Button {
                model.callMinimized = false
            } label: {
                label
            }
            .buttonStyle(.plain)
        }
    }

    private var label: some View {
        HStack(spacing: 12) {
            StatusDot(color: Theme.info)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.calls.count > 1 ? "\(model.calls.count) calls" : (model.currentRow?.title ?? "Call"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.text)
                if let row = model.currentRow {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(callStatusText(row, now: context.date))
                            .font(.footnote)
                            .monospacedDigit()
                            .foregroundStyle(Theme.info)
                    }
                }
            }
            Spacer()
            Text("Return")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.info)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 60)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.raisedLine))
        .contentShape(Rectangle())
    }
}
