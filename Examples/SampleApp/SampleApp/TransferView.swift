import SwiftUI
import BaresipKit

struct TransferView: View {
    @EnvironmentObject private var model: CallModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if let held = model.heldRow, let current = model.currentRow {
                    Section("On hold") {
                        CallSummary(row: held, color: Palette.secondaryText)
                    }
                    Section("Consulting") {
                        CallSummary(row: current, color: Palette.green)
                    }
                    Section {
                        Button("Complete transfer") {
                            Task {
                                await model.completeTransfer()
                                dismiss()
                            }
                        }
                        .fontWeight(.semibold)
                        Button("End consultation, back to \(held.title)", role: .destructive) {
                            Task {
                                await model.endConsultation()
                                dismiss()
                            }
                        }
                    } footer: {
                        Text(
                            """
                            \(held.title) and \(current.title) are connected to each other. \(current.title)'s \
                            phone doesn't ring again; both of your calls end.
                            """
                        )
                    }
                } else {
                    Section {
                        TextField("Number, user or SIP URI", text: $model.transferTarget)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("transfer.target")
                        Button("Consult first") {
                            Task { await model.consult() }
                        }
                        .disabled(model.transferTarget.trimmed.isEmpty)
                        Button("Transfer now (blind)") {
                            Task {
                                await model.blindTransfer()
                                dismiss()
                            }
                        }
                        .disabled(model.transferTarget.trimmed.isEmpty)
                    } header: {
                        Text("Transfer \(model.currentRow?.title ?? "call") to")
                    } footer: {
                        Text(
                            """
                            Consult puts this call on hold and calls the target so you can talk first. Blind sends \
                            the call on right away.
                            """
                        )
                    }
                }
            }
            .navigationTitle("Transfer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
