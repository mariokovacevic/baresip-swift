import Foundation

public struct BaresipAccountID: Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    public var description: String { "account#\(rawValue)" }
}

public struct BaresipCallID: Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    public var description: String { "call#\(rawValue)" }
}
