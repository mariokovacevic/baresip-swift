import SwiftUI

/// A door's settings: its name, address and code, and how it opens. A saved door keeps every
/// change at once; a new one is added with the button at the bottom.
struct DoorView: View {
    @EnvironmentObject private var model: CallModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Door
    @State private var confirmRemove = false
    private let isNew: Bool

    init(door: Door) {
        _draft = State(initialValue: door)
        isNew = door.address.isEmpty && door.name.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenTitle(title: isNew ? "New door" : draft.title)
                if !isNew, draft.hasCamera {
                    picture
                }
                StackedField(title: "Name", text: $draft.name, prompt: "Front door")
                StackedField(title: "Door station (SIP user or address)", text: $draft.address,
                             prompt: "door1 or sip:door1@pbx.example.com", keyboard: .emailAddress)
                TitledSection(title: "Opening",
                              note: "The code goes to the door as tones. Without one the door only talks.") {
                    Card {
                        HStack(spacing: 12) {
                            Image(systemName: "lock")
                                .foregroundStyle(Theme.brass)
                                .accessibilityHidden(true)
                            Text("Door code")
                                .foregroundStyle(Theme.text)
                            SecretField(title: "Door code", text: $draft.code, prompt: "Digits, * or #",
                                        keyboard: .phonePad, identifier: "door.code")
                                .foregroundStyle(Theme.text)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 56)
                        RowDivider()
                        ToggleRow(title: "Open from the notification",
                                  detail: "Answers, sends the code and hangs up", isOn: $draft.opensFromNotification)
                        RowDivider()
                        ToggleRow(title: "Ask for Face ID first", detail: "Nobody else opens with your phone",
                                  isOn: $draft.asksForFaceID)
                        RowDivider()
                        ToggleRow(title: "Hang up after opening", detail: "Off keeps the call until you end it",
                                  isOn: $draft.hangsUpAfterOpening)
                    }
                }
                Card {
                    ToggleRow(title: "The door has a camera", detail: "Shows its picture on the Doors screen",
                              isOn: $draft.hasCamera)
                }
                if isNew {
                    Button("Add door") {
                        model.save(draft)
                        dismiss()
                    }
                    .buttonStyle(FilledButtonStyle(kind: .light))
                    .disabled(draft.address.trimmed.isEmpty)
                } else {
                    Button("Remove this door", role: .destructive) { confirmRemove = true }
                        .buttonStyle(FilledButtonStyle(kind: .danger))
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .titledScreen(isNew ? "New door" : draft.title)
        .onChange(of: draft) { door in
            if !isNew {
                model.save(door)
            }
        }
        .confirmationDialog("Remove \(draft.title)?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                model.remove(draft)
                dismiss()
            }
        }
    }

    private var picture: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return HStack(spacing: 16) {
            Image(systemName: "person")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(Theme.pictureMark)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 10) {
                Text(lastRingText)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondary)
                Button {
                    Task { await model.look(at: draft) }
                } label: {
                    Label("Look at the door", systemImage: "video")
                }
                .buttonStyle(FilledButtonStyle(kind: .raised, height: 44, radius: 12, expands: false))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 150)
        .background(Theme.picture, in: shape)
        .overlay(shape.stroke(Theme.line))
    }

    private var lastRingText: String {
        guard let record = model.lastRecord(of: draft) else { return "No ring yet" }
        return "Last ring \(record.startedAt.formatted(date: .abbreviated, time: .shortened))"
    }
}
