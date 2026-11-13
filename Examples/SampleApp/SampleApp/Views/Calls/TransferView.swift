import SwiftUI
import BaresipKit

/// Hands the call to someone else: ask them first while the call waits, or send it on at once.
struct TransferView: View {
    @EnvironmentObject private var model: CallModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let held = model.heldRow, let current = model.currentRow {
                    consulting(held: held, current: current)
                } else {
                    choosing
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.bar.ignoresSafeArea())
        .navigationTitle("Transfer the call")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var choosing: some View {
        Note(text: "\(model.currentRow?.title ?? "The call") waits on hold while you ask.")
        StackedField(title: "Transfer to", text: $model.transferTarget, prompt: "Number or address",
                     keyboard: .asciiCapable)
            .accessibilityIdentifier("transfer.target")
        if !recent.isEmpty {
            TitledSection(title: "Recent") {
                Card {
                    ForEach(Array(recent.enumerated()), id: \.element.uri) { index, record in
                        if index > 0 {
                            RowDivider()
                        }
                        Button {
                            model.transferTarget = record.uri
                        } label: {
                            HStack(spacing: 12) {
                                Text(record.name)
                                    .foregroundStyle(Theme.text)
                                Spacer()
                                Text(record.user)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.secondary)
                                if model.transferTarget == record.uri {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Theme.info)
                                        .accessibilityLabel("Chosen")
                                }
                            }
                            .padding(.horizontal, 16)
                            .frame(minHeight: 52)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        VStack(alignment: .leading, spacing: 6) {
            Button("Ask \(targetName) first") {
                Task { await model.consult() }
            }
            .buttonStyle(FilledButtonStyle(kind: .light, height: 56))
            Note(text: "You talk to \(targetName), then hand the call over or come back.")
        }
        .disabled(model.transferTarget.trimmed.isEmpty)
        .padding(.top, 8)
        VStack(alignment: .leading, spacing: 6) {
            Button("Transfer now") {
                Task {
                    await model.blindTransfer()
                    dismiss()
                }
            }
            .buttonStyle(FilledButtonStyle(kind: .raised))
            Note(text: "The call rings \(targetName) and you leave it at once.")
        }
        .disabled(model.transferTarget.trimmed.isEmpty)
    }

    @ViewBuilder
    private func consulting(held: CallRow, current: CallRow) -> some View {
        Note(text: "You are asking \(current.title). \(held.title) hears nothing.")
        party(current, status: Theme.info, highlighted: true)
        party(held, status: Theme.secondary, highlighted: false)
        Button("Hand \(held.title) to \(current.title)") {
            Task {
                await model.completeTransfer()
                dismiss()
            }
        }
        .buttonStyle(FilledButtonStyle(kind: .light, height: 56))
        .padding(.top, 8)
        Button("End this and return to \(held.title)") {
            Task {
                await model.endConsultation()
                dismiss()
            }
        }
        .buttonStyle(FilledButtonStyle(kind: .raised))
    }

    private func party(_ row: CallRow, status: Color, highlighted: Bool) -> some View {
        Card(highlighted: highlighted) {
            HStack(spacing: 12) {
                Avatar(initials: row.initials, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(row.title)
                        .font(.display(22))
                        .foregroundStyle(Theme.text)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(callStatusText(row, now: context.date))
                            .textCase(.uppercase)
                            .font(.footnote.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(status)
                    }
                }
            }
            .padding(14)
        }
    }

    private var targetName: String {
        let target = model.transferTarget.trimmed
        return target.isEmpty ? "them" : CallRow.displayName(target)
    }

    /// People called recently, other than the current call, newest first.
    private var recent: [CallRecord] {
        var seen: Set<String> = [model.currentRow?.uri ?? ""]
        var result: [CallRecord] = []
        for record in model.history where !record.uri.isEmpty && seen.insert(record.uri).inserted {
            result.append(record)
            if result.count == 4 {
                break
            }
        }
        return result
    }
}
