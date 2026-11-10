import Foundation

struct SIPIdentity: Equatable {
    let user: String
    let host: String

    init(_ uri: String) {
        var value = uri.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let open = value.firstIndex(of: "<"), let close = value.lastIndex(of: ">"), open < close {
            value = String(value[value.index(after: open) ..< close])
        }
        for scheme in ["sips:", "sip:", "tel:"] where value.hasPrefix(scheme) {
            value = String(value.dropFirst(scheme.count))
        }
        if let end = value.firstIndex(where: { $0 == ";" || $0 == "?" }) {
            value = String(value[..<end])
        }
        let parts = value.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        user = parts.first ?? ""
        host = parts.count == 2 ? Self.hostWithoutPort(parts[1]) : ""
    }

    var isEmpty: Bool {
        user.isEmpty && host.isEmpty
    }

    private static func hostWithoutPort(_ hostAndPort: String) -> String {
        if hostAndPort.hasPrefix("["), let close = hostAndPort.firstIndex(of: "]") {
            return String(hostAndPort[...close])
        }
        return hostAndPort.split(separator: ":").first.map(String.init) ?? hostAndPort
    }
}
