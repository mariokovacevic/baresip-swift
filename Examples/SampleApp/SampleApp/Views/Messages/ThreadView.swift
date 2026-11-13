import SwiftUI
import BaresipKit

struct ThreadView: View {
    @EnvironmentObject private var model: CallModel
    @Environment(\.dismiss) private var dismiss
    let peerURI: String
    var overCall = false
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if let first = thread.first {
                            Text(first.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Theme.secondary)
                                .padding(.bottom, 4)
                        }
                        ForEach(thread) { message in
                            Bubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: thread.count) { _ in
                    if let last = thread.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                    model.markRead(peerURI)
                }
            }
            composer
        }
        .onAppear {
            model.openChatPeer = name
            model.markRead(peerURI)
        }
        .onDisappear {
            if model.openChatPeer == name {
                model.openChatPeer = nil
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.bar, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(title)
                        .font(.display(20))
                        .foregroundStyle(Theme.text)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                if overCall {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("chat.done")
                } else {
                    Button {
                        call(video: false)
                    } label: {
                        RoundIcon(systemImage: "phone", size: 36)
                    }
                    .accessibilityLabel("Call \(title)")
                    Button {
                        call(video: true)
                    } label: {
                        RoundIcon(systemImage: "video", size: 36)
                    }
                    .accessibilityLabel("Video call \(title)")
                }
            }
        }
    }

    private var composer: some View {
        HStack(spacing: 8) {
            TextField("Message", text: $draft, axis: .vertical)
                .lineLimit(1 ... 4)
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.field))
            Button {
                send()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.background)
                    .frame(width: 48, height: 48)
                    .background(Theme.text, in: Circle())
            }
            .disabled(draft.trimmed.isEmpty)
            .opacity(draft.trimmed.isEmpty ? 0.45 : 1)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(Theme.bar)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.barLine).frame(height: 1)
        }
    }

    private var name: String {
        CallRow.displayName(peerURI)
    }

    private var title: String {
        model.door(for: peerURI)?.title ?? name
    }

    private var subtitle: String {
        let uri = model.normalizedDestination(peerURI).replacingOccurrences(of: "sip:", with: "")
        let address = uri.split(whereSeparator: { $0 == ";" || $0 == "?" }).first.map(String.init) ?? uri
        return overCall ? "\(address), in call" : address
    }

    private var thread: [ChatMessage] {
        model.messages(with: name)
    }

    private func call(video: Bool) {
        model.destination = peerURI
        Task { await model.call(video: video) }
    }

    private func send() {
        let text = draft.trimmed
        guard !text.isEmpty else { return }
        draft = ""
        Task { await model.send(text, to: peerURI) }
    }
}
