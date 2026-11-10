import SwiftUI

/// Sends DTMF to a door station: on the current call, or on a new audio call to the entered
/// address. Waits for the station's reply digit when one is set, then hangs up if asked to.
struct DTMFEntryView: View {
    @EnvironmentObject private var model: CallModel
    @Environment(\.dismiss) private var dismiss
    @State private var digits = ""
    @AppStorage("dtmf.ack") private var ack = ""
    @AppStorage("dtmf.hangUp") private var hangUp = true

    private static let ackChoices = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "#"]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(digits.isEmpty ? " " : digits)
                    .font(.system(size: 34, weight: .medium))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("dtmf.digits")
                DTMFPad { digit in digits.append(digit) }
                Button {
                    if !digits.isEmpty {
                        digits.removeLast()
                    }
                } label: {
                    Image(systemName: "delete.left")
                        .font(.title2)
                        .frame(width: 76, height: 44)
                }
                .disabled(digits.isEmpty)
                .accessibilityLabel("Delete")

                VStack(spacing: 0) {
                    Picker("Expected reply", selection: $ack) {
                        Text("None").tag("")
                        ForEach(Self.ackChoices, id: \.self) { Text($0).tag($0) }
                    }
                    .frame(minHeight: 44)
                    Divider()
                    Toggle("Hang up when done", isOn: $hangUp)
                        .frame(minHeight: 44)
                }
                .padding(.horizontal, 16)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

                Text(targetText)
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("DTMF")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Send") {
                    let request = DTMFRequest(digits: digits, ack: ack, hangUp: hangUp)
                    dismiss()
                    Task { await model.sendDTMFRequest(request) }
                }
                .disabled(!canSend)
                .accessibilityIdentifier("dtmf.send")
            }
        }
    }

    private var canSend: Bool {
        !digits.isEmpty && (model.currentCall != nil || !model.destination.trimmed.isEmpty)
    }

    private var targetText: String {
        let timeout = DTMFRequest.ackTimeout.components.seconds
        let reply = ack.isEmpty ? "" : " Waits up to \(timeout) s for \(ack) from the station."
        if let row = model.currentRow {
            return "Sends on the current call with \(row.title).\(reply)"
        }
        if model.destination.trimmed.isEmpty {
            return "Enter an address on the Calls screen first."
        }
        return "Calls \(model.destination.trimmed) and sends once it is connected.\(reply)"
    }
}
