import Foundation
import UIKit
import BaresipKit
import BaresipKitSwiftUI

/// A message from the other side of the call, shown over the call's video for a few seconds.
struct CallCaption: Identifiable, Equatable {
    let id = UUID()
    let sender: String
    let text: String

    static let limit = 3

    /// Long enough to read: four seconds and a little more per word, at most ten.
    var lifetime: Duration {
        let words = text.split(whereSeparator: \.isWhitespace).count
        return .milliseconds(min(10000, 4000 + words * 300))
    }
}

extension CallModel {
    /// Files a received message and shows it where it is seen: as a caption on the call screen
    /// when the call's other side sent it, in the open chat, or as a notification while the app
    /// is in the background, which is where the system call screen of CallKit or
    /// LiveCommunicationKit leaves it.
    func receive(_ message: BaresipMessage) {
        let text = message.text ?? "<\(message.contentType), \(message.body.count) bytes>"
        let peer = CallRow.displayName(message.from)
        let inOpenChat = openChatPeer == peer
        messages.append(ChatMessage(id: UUID(), messageID: nil, peer: message.from, text: text, outgoing: false,
                                    status: .received, read: inOpenChat))
        append("message from \(message.from)")
        guard UIApplication.shared.applicationState == .active else {
            PreviewNotifications.showMessage(from: senderName(message.from), text: text,
                                             onFailure: notificationFailed)
            return
        }
        guard !inOpenChat, let call = callOnScreen, !callMinimized, incoming == nil,
              phone?.call(withPeer: message.from) === call else { return }
        showCaption(CallCaption(sender: senderName(message.from), text: text))
    }

    func showCaption(_ caption: CallCaption) {
        captions.append(caption)
        if captions.count > CallCaption.limit {
            captions.removeFirst(captions.count - CallCaption.limit)
        }
        UIAccessibility.post(notification: .announcement, argument: "\(caption.sender): \(caption.text)")
        Task { [weak self] in
            try? await Task.sleep(for: caption.lifetime)
            self?.captions.removeAll { $0.id == caption.id }
        }
    }

    /// Unread messages from the user of `peer`, or from everybody without a peer.
    func unreadCount(from peer: String? = nil) -> Int {
        messages.filter { message in
            guard !message.outgoing, !message.read else { return false }
            return peer.map { CallRow.displayName(message.peer) == CallRow.displayName($0) } ?? true
        }.count
    }

    /// Marks the conversation with the user of `peer` read, as its thread shows it.
    func markRead(_ peer: String) {
        let user = CallRow.displayName(peer)
        for index in messages.indices where !messages[index].read && CallRow.displayName(messages[index].peer) == user {
            messages[index].read = true
        }
    }

    /// Opens the chat with the call's other side over the call screen; its captions stop
    /// while it is open.
    func openCallChat() {
        guard let call = callOnScreen else { return }
        captions.removeAll()
        showCallChat = call.remoteURI
    }

    private func senderName(_ from: String) -> String {
        if let call = phone?.call(withPeer: from), let door = door(of: call) {
            return door.title
        }
        if let call = phone?.call(withPeer: from), !call.remoteDisplayName.isEmpty {
            return call.remoteDisplayName
        }
        return CallRow.displayName(from)
    }
}
