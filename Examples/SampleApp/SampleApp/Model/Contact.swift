import Foundation

/// A person or desk the user calls and writes to often: a name and a number or SIP address.
struct Contact: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = ""
    /// A number on the user's server, or a full SIP address.
    var address = ""

    var title: String {
        let trimmed = name.trimmed
        return trimmed.isEmpty ? CallRow.displayName(address.trimmed) : trimmed
    }

    var initials: String {
        CallRow.initials(title)
    }
}
