import SwiftUI
import BaresipKit

/// The calls while there are several: one talks, the others wait on hold.
struct CallsView: View {
    @EnvironmentObject private var model: CallModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenTitle(title: "Calls")
                Note(text: "One call talks, the other waits. Resuming one puts the other on hold.")
                ForEach(model.calls) { row in
                    CallCard(row: row)
                }
                if let held = model.heldRow, let current = model.currentRow {
                    Button {
                        Task { await model.completeTransfer() }
                    } label: {
                        LinkRowLabel(title: "Connect the two and leave", value: nil,
                                     systemImage: "arrow.left.arrow.right")
                    }
                    .buttonStyle(.plain)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line))
                    Note(text: "\(held.title) and \(current.title) then talk to each other.")
                }
                Button {
                    model.tab = .keypad
                } label: {
                    Label("New call", systemImage: "plus")
                }
                .buttonStyle(FilledButtonStyle(kind: .raised))
            }
            .padding(16)
        }
        .titledScreen("Calls")
    }
}

private struct CallCard: View {
    @EnvironmentObject private var model: CallModel
    let row: CallRow

    var body: some View {
        Card(highlighted: isCurrent) {
            Button {
                Task {
                    if row.state == .incoming {
                        await model.showIncoming(row.id)
                    } else {
                        await model.switchTo(row.id)
                        model.callMinimized = false
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Avatar(initials: row.initials, size: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.door(for: row.uri)?.title ?? row.title)
                            .font(.display(22))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(callStatusText(row, now: context.date) + (row.codec.isEmpty ? "" : ", \(row.codec)"))
                                .textCase(.uppercase)
                                .font(.footnote.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(isCurrent ? Theme.info : Theme.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Theme.secondary)
                        .accessibilityHidden(true)
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("calls.row")
            HStack(spacing: 8) {
                if row.state != .incoming {
                    Button(row.isHeld ? "Resume" : "Hold") {
                        Task {
                            if row.isHeld {
                                await model.switchTo(row.id)
                            } else {
                                await model.toggleHold(row.id)
                            }
                        }
                    }
                    .buttonStyle(FilledButtonStyle(kind: row.isHeld ? .light : .raised, height: 48))
                }
                Button {
                    Task { await model.hangup(row.id) }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .semibold))
                }
                .buttonStyle(HangUpButtonStyle(size: 48))
                .accessibilityLabel("Hang up the call with \(row.title)")
            }
            .padding([.horizontal, .bottom], 14)
        }
    }

    private var isCurrent: Bool {
        row.id == model.currentCall
    }
}

/// The red square that ends a call.
struct HangUpButtonStyle: ButtonStyle {
    var size: CGFloat = 64

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Theme.alert)
            .frame(width: size, height: size)
            .background(Theme.hangUp, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
