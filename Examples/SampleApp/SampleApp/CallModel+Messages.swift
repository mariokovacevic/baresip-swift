import Foundation
import BaresipKit

extension CallModel {
    var conversations: [(peer: String, last: ChatMessage)] {
        var latest: [String: (position: Int, message: ChatMessage)] = [:]
        for (position, message) in messages.enumerated() {
            latest[CallRow.displayName(message.peer)] = (position, message)
        }
        return latest
            .sorted { $0.value.position > $1.value.position }
            .map { (peer: $0.key, last: $0.value.message) }
    }

    func messages(with peer: String) -> [ChatMessage] {
        messages.filter { CallRow.displayName($0.peer) == peer }
    }

    func sendMessage() async {
        guard let engine else { return }
        let to = normalizedDestination(messageTo)
        let text = messageText
        guard !to.isEmpty, !text.isEmpty else { return }
        do {
            let id = try await engine.sendMessage(to: to, text: text, accountID: accountID)
            let status = earlyStatuses.removeValue(forKey: id) ?? .sending
            messages.append(ChatMessage(
                id: UUID(),
                messageID: id,
                peer: to,
                text: text,
                outgoing: true,
                status: status
            ))
            messageText = ""
        } catch {
            messages.append(ChatMessage(id: UUID(), messageID: nil, peer: to, text: text, outgoing: true,
                                        status: .failed("\(error)")))
        }
    }
}
