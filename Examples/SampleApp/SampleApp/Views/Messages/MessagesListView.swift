import SwiftUI
import BaresipKit

struct MessagesListView: View {
    @EnvironmentObject private var model: CallModel
    @State private var askPeer = false
    @State private var newPeer = ""
    @State private var openPeer = ""
    @State private var openThread = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenTitle(title: "Messages")
                if model.conversations.isEmpty {
                    Card {
                        Text("No messages yet. Write to a person or a desk on your intercom server.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondary)
                            .padding(16)
                    }
                } else {
                    Card {
                        ForEach(Array(model.conversations.enumerated()), id: \.element.peer) { index, conversation in
                            if index > 0 {
                                RowDivider()
                            }
                            NavigationLink {
                                ThreadView(peerURI: conversation.last.peer)
                            } label: {
                                ConversationRow(peer: conversation.peer, last: conversation.last)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Note(text: """
                Messages go through your intercom server, to people and desks on it. They arrive while \
                Zvono is open or reachable.
                """)
            }
            .padding(16)
        }
        .titledScreen("Messages")
        .navigationDestination(isPresented: $openThread) {
            ThreadView(peerURI: openPeer)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newPeer = ""
                    askPeer = true
                } label: {
                    RoundIcon(systemImage: "square.and.pencil", size: 36)
                }
                .accessibilityLabel("New message")
            }
        }
        .alert("New message", isPresented: $askPeer) {
            TextField("Number or address", text: $newPeer)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) {}
            Button("Write") {
                openPeer = newPeer.trimmed
                openThread = !openPeer.isEmpty
            }
        } message: {
            Text("Whom do you want to write to?")
        }
    }
}

private struct ConversationRow: View {
    let peer: String
    let last: ChatMessage

    var body: some View {
        HStack(spacing: 12) {
            Avatar(initials: CallRow.initials(peer))
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(peer)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(last.date.formatted(date: .omitted, time: .shortened))
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(Theme.secondary)
                }
                Text(preview)
                    .font(.subheadline)
                    .foregroundStyle(isFailed ? Theme.alert : Theme.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var isFailed: Bool {
        if case .failed = last.status {
            return true
        }
        return false
    }

    private var preview: String {
        guard last.outgoing else { return last.text }
        return "You: \(last.text)" + (isFailed ? " Not delivered" : "")
    }
}
