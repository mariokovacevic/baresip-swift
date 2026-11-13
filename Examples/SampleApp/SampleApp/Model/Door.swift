import Foundation

/// A door station the user rings and opens: where it is, the code that opens it, and how.
struct Door: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = ""
    /// The door station's SIP user or URI.
    var address = ""
    /// DTMF that opens the door; empty when the door only talks.
    var code = ""
    var hasCamera = true
    /// Whether a ringing call's notification offers Open door.
    var opensFromNotification = true
    /// Whether opening from the app asks for Face ID or the passcode first.
    var asksForFaceID = false
    var hangsUpAfterOpening = true

    var canOpen: Bool {
        !code.trimmed.isEmpty
    }

    var title: String {
        let trimmed = name.trimmed
        return trimmed.isEmpty ? CallRow.displayName(address) : trimmed
    }

    /// The SIP user the door calls from, to tell its calls apart from others.
    var user: String {
        CallRow.displayName(address.trimmed)
    }

    var openRequest: DTMFRequest {
        DTMFRequest(digits: code.trimmed, ack: "", hangUp: hangsUpAfterOpening)
    }
}

/// The app's tabs.
enum AppTab: Hashable {
    case doors
    case activity
    case keypad
    case messages
    case settings
}
