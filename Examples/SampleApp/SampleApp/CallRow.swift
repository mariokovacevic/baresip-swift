import Foundation
import BaresipKit

struct CallRow: Identifiable, Equatable {
    let id: BaresipCallID
    var remote: String
    var state: BaresipCallState
    var outgoing: Bool
    var hasVideo = false
    var codec: String = ""
    var connectedAt: Date?

    var title: String {
        CallRow.displayName(remote)
    }

    var initials: String {
        CallRow.initials(title)
    }

    var isHeld: Bool {
        state == .paused || state == .pausing
    }

    static func displayName(_ remote: String) -> String {
        var value = remote
        for scheme in ["sips:", "sip:", "tel:"] where value.hasPrefix(scheme) {
            value = String(value.dropFirst(scheme.count))
        }
        if let semicolon = value.firstIndex(of: ";") {
            value = String(value[..<semicolon])
        }
        if let at = value.firstIndex(of: "@") {
            value = String(value[..<at])
        }
        return value.isEmpty ? remote : value
    }

    static func initials(_ name: String) -> String {
        let words = name.split(whereSeparator: { $0 == " " || $0 == "." || $0 == "-" }).prefix(2)
        let letters = words.compactMap(\.first).map { String($0).uppercased() }.joined()
        return letters.isEmpty ? String(name.prefix(2)).uppercased() : letters
    }
}
