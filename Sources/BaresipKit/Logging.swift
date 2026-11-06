import Foundation
import os
import BaresipKitCore

public enum BaresipLogLevel: Int, Sendable, Comparable, Codable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3

    public static func < (lhs: BaresipLogLevel, rhs: BaresipLogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var c: bsk_log_level { bsk_log_level(UInt32(rawValue)) }

    init(_ c: bsk_log_level) {
        self = BaresipLogLevel(rawValue: Int(c.rawValue)) ?? .info
    }
}

public enum BaresipLogDomain: Int, Sendable, Codable {
    case core = 0
    case sip = 1
    case media = 2

    init(_ c: bsk_log_domain) {
        self = BaresipLogDomain(rawValue: Int(c.rawValue)) ?? .core
    }
}

public struct BaresipLogEntry: Sendable {
    public let level: BaresipLogLevel
    public let domain: BaresipLogDomain
    public let message: String
}

public typealias BaresipLogHandler = @Sendable (BaresipLogEntry) -> Void

public enum BaresipOSLog {
    public static func handler(subsystem: String = "BaresipKit") -> BaresipLogHandler {
        let core = Logger(subsystem: subsystem, category: "core")
        let sip = Logger(subsystem: subsystem, category: "sip")
        let media = Logger(subsystem: subsystem, category: "media")
        return { entry in
            let logger: Logger
            switch entry.domain {
            case .core: logger = core
            case .sip: logger = sip
            case .media: logger = media
            }
            switch entry.level {
            case .debug: logger.debug("\(entry.message, privacy: .public)")
            case .info: logger.info("\(entry.message, privacy: .public)")
            case .warning: logger.warning("\(entry.message, privacy: .public)")
            case .error: logger.error("\(entry.message, privacy: .public)")
            }
        }
    }
}
