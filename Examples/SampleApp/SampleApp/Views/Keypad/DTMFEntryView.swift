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
            VStack(spacing: 18) {
                HStack {
                    Text(digits.isEmpty ? "Code" : digits)
                        .font(.displayMedium(34))
                        .tracking(2)
                        .foregroundStyle(digits.isEmpty ? Theme.secondary : Theme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .accessibilityIdentifier("dtmf.digits")
                    Spacer()
                    Button {
                        if !digits.isEmpty {
                            digits.removeLast()
                        }
                    } label: {
                        Image(systemName: "delete.left")
                            .font(.title3)
                            .foregroundStyle(Theme.secondary)
                            .frame(width: 48, height: 48)
                    }
                    .disabled(digits.isEmpty)
                    .accessibilityLabel("Delete")
                }
                .padding(.leading, 18)
                .padding(.trailing, 6)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line))

                DialPad(keySize: 68, showsLetters: false) { digit in digits.append(digit) }

                Card {
                    Picker(selection: $ack) {
                        Text("None").tag("")
                        ForEach(Self.ackChoices, id: \.self) { Text($0).tag($0) }
                    } label: {
                        Text("Expected reply")
                            .foregroundStyle(Theme.text)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 50)
                    RowDivider()
                    ToggleRow(title: "Hang up when done", isOn: $hangUp)
                }

                Note(text: targetText)
                    .multilineTextAlignment(.center)
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Send a code")
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
        .tint(Theme.info)
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
            return "Enter an address on the keypad first."
        }
        return "Calls \(model.destination.trimmed) and sends once it is connected.\(reply)"
    }
}
