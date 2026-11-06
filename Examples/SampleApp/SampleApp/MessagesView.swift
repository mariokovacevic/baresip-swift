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

struct ThreadView: View {
    @EnvironmentObject private var model: CallModel
    let peerURI: String
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(thread) { message in
                            Bubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                }
                .onChange(of: thread.count) { _, _ in
                    if let last = thread.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            Divider()
            HStack(spacing: 8) {
                TextField("SIP message", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .overlay(RoundedRectangle(cornerRadius: 19).stroke(Color(.systemGray4)))
                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Palette.blue, in: Circle())
                }
                .disabled(draft.trimmed.isEmpty)
                .accessibilityLabel("Send")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
        }
        .navigationTitle(CallRow.displayName(peerURI))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.destination = peerURI
                    Task { await model.call(video: false) }
                } label: {
                    Image(systemName: "phone")
                }
                .accessibilityLabel("Call \(CallRow.displayName(peerURI))")
            }
        }
    }

    private var thread: [ChatMessage] {
        model.messages(with: CallRow.displayName(peerURI))
    }

    private func send() {
        let text = draft.trimmed
        guard !text.isEmpty else { return }
        model.messageTo = peerURI
        model.messageText = text
        draft = ""
        Task { await model.sendMessage() }
    }
}

struct Bubble: View {
    let message: ChatMessage

    var body: some View {
        VStack(alignment: message.outgoing ? .trailing : .leading, spacing: 3) {
            Text(message.text)
                .font(.body)
                .foregroundStyle(foreground)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(background, in: RoundedRectangle(cornerRadius: 18))
            if let status = statusLine {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(isFailed ? Palette.destructive : Palette.secondaryText)
            }
        }
        .frame(maxWidth: 280, alignment: message.outgoing ? .trailing : .leading)
        .frame(maxWidth: .infinity, alignment: message.outgoing ? .trailing : .leading)
    }

    private var isFailed: Bool {
        if case .failed = message.status { return true }
        return false
    }

    private var foreground: Color {
        if isFailed { return Palette.secondaryText }
        return message.outgoing ? .white : .primary
    }

    private var background: Color {
        if isFailed { return Color(.systemGray6) }
        return message.outgoing ? Palette.blue : Color(.systemGray5)
    }

    private var statusLine: String? {
        switch message.status {
        case .sending: return "Sending…"
        case .delivered: return "Delivered"
        case .failed(let reason): return "Not delivered · \(reason)"
        case .received: return nil
        }
    }
}

struct LogView: View {
    @EnvironmentObject private var model: CallModel

    var body: some View {
        List(Array(model.log.enumerated().reversed()), id: \.offset) { _, line in
            Text(line)
                .font(.caption.monospaced())
        }
        .navigationTitle("Log")
    }
}
