import SwiftUI
import BaresipKit

struct MessagesListView: View {
    @EnvironmentObject private var model: CallModel
    @State private var newPeer = ""

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("To (number, user or SIP URI)", text: $newPeer)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    NavigationLink("New") {
                        ThreadView(peerURI: newPeer)
                    }
                    .disabled(newPeer.trimmed.isEmpty)
                    .fixedSize()
                }
            }
            if model.conversations.isEmpty {
                Text("No messages yet")
                    .foregroundStyle(Palette.secondaryText)
            } else {
                Section {
                    ForEach(model.conversations, id: \.peer) { conversation in
                        NavigationLink {
                            ThreadView(peerURI: conversation.last.peer)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(conversation.peer)
                                    .font(.headline)
                                Text(conversation.last.text)
                                    .font(.subheadline)
                                    .foregroundStyle(Palette.secondaryText)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Messages")
    }
}
