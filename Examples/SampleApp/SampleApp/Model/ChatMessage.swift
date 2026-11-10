import Foundation
import BaresipKit

struct ChatMessage: Identifiable, Equatable {
    enum Status: Equatable {
        case sending
        case delivered
        case failed(String)
        case received
    }

    let id: UUID
    let messageID: BaresipMessageID?
    let peer: String
    let text: String
    let outgoing: Bool
    var status: Status
}
