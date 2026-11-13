import SwiftUI

/// A contact's name and address. A saved contact keeps every change at once; a new one is added
/// with the button at the bottom.
struct ContactView: View {
    @EnvironmentObject private var model: CallModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Contact
    @State private var confirmRemove = false
    private let isNew: Bool

    init(contact: Contact) {
        _draft = State(initialValue: contact)
        isNew = contact.address.isEmpty && contact.name.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenTitle(title: isNew ? "New contact" : draft.title)
                if !isNew {
                    actions
                }
                StackedField(title: "Name", text: $draft.name, prompt: "Neighbour")
                StackedField(title: "Number or address", text: $draft.address,
                             prompt: "101 or sip:101@pbx.example.com", keyboard: .emailAddress)
                if isNew {
                    Button("Add contact") {
                        model.save(draft)
                        dismiss()
                    }
                    .buttonStyle(FilledButtonStyle(kind: .light))
                    .disabled(draft.address.trimmed.isEmpty)
                    .accessibilityIdentifier("contact.add")
                } else {
                    Button("Remove this contact", role: .destructive) { confirmRemove = true }
                        .buttonStyle(FilledButtonStyle(kind: .danger))
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .titledScreen(isNew ? "New contact" : draft.title)
        .onChange(of: draft) { contact in
            if !isNew {
                model.save(contact)
            }
        }
        .confirmationDialog("Remove \(draft.title)?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                model.remove(draft)
                dismiss()
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                Task { await model.call(draft, video: false) }
            } label: {
                Label("Call", systemImage: "phone.fill")
            }
            .buttonStyle(FilledButtonStyle(kind: .light, height: 48))
            .accessibilityIdentifier("contact.call")
            Button {
                Task { await model.call(draft, video: true) }
            } label: {
                Label("Video", systemImage: "video")
            }
            .buttonStyle(FilledButtonStyle(kind: .raised, height: 48))
            .accessibilityIdentifier("contact.video")
            NavigationLink {
                ThreadView(peerURI: draft.address.trimmed)
            } label: {
                Label("Message", systemImage: "bubble.left")
            }
            .buttonStyle(FilledButtonStyle(kind: .raised, height: 48))
            .accessibilityIdentifier("contact.message")
        }
        .disabled(draft.address.trimmed.isEmpty)
    }
}

/// The saved contacts on the keypad, each with message, call and video.
struct ContactsSection: View {
    @EnvironmentObject private var model: CallModel
    let onMessage: (Contact) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionTitle(title: "Contacts")
                Spacer()
                NavigationLink("Add") {
                    ContactView(contact: Contact())
                }
                .font(.subheadline.weight(.medium))
                .accessibilityIdentifier("contacts.add")
            }
            if model.contacts.isEmpty {
                Card {
                    Text("Save the people you call often: a neighbour, the reception, the caretaker.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondary)
                        .padding(16)
                }
            } else {
                Card {
                    ForEach(Array(model.contacts.enumerated()), id: \.element.id) { index, contact in
                        if index > 0 {
                            RowDivider()
                        }
                        row(contact)
                    }
                }
            }
        }
    }

    private func row(_ contact: Contact) -> some View {
        HStack(spacing: 12) {
            NavigationLink {
                ContactView(contact: contact)
            } label: {
                HStack(spacing: 12) {
                    Avatar(initials: contact.initials)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                        Text(contact.address)
                            .font(.footnote)
                            .foregroundStyle(Theme.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(contact.title)")
            button("bubble.left", label: "Message \(contact.title)") { onMessage(contact) }
            button("phone.fill", label: "Call \(contact.title)") {
                Task { await model.call(contact, video: false) }
            }
            button("video", label: "Video call \(contact.title)") {
                Task { await model.call(contact, video: true) }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func button(_ systemImage: String, label: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            RoundIcon(systemImage: systemImage, size: 40)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
