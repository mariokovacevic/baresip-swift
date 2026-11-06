import SwiftUI
import BaresipKit

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
