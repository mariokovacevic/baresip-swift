import Foundation
import BaresipKitCore

public enum BaresipStatus: Int, Sendable, Codable {
    case ok = 0
    case invalidArgument = 1
    case invalidState = 2
    case notFound = 3
    case noMemory = 4
    case unsupported = 5
    case busy = 6
    case timeout = 7
    case network = 8
    case tls = 9
    case authentication = 10
    case sip = 11
    case media = 12
    case bufferTooSmall = 13
    case internalError = 14

    init(_ c: bsk_status) {
        self = BaresipStatus(rawValue: Int(c.rawValue)) ?? .internalError
    }
}

public struct BaresipError: Error, Sendable, Equatable, CustomStringConvertible {
    public let status: BaresipStatus
    public let systemErrno: Int32
    public let sipStatus: Int?
    public let sipReason: String
    public let message: String

    public init(status: BaresipStatus, systemErrno: Int32 = 0, sipStatus: Int? = nil,
                sipReason: String = "", message: String = "") {
        self.status = status
        self.systemErrno = systemErrno
        self.sipStatus = sipStatus
        self.sipReason = sipReason
        self.message = message
    }

    init(_ c: bsk_error) {
        status = BaresipStatus(c.status)
        systemErrno = c.sys_errno
        sipStatus = c.sip_status == 0 ? nil : Int(c.sip_status)
        sipReason = stringFromCArray(c.sip_reason)
        message = stringFromCArray(c.message)
    }

    init(status: bsk_status, _ c: bsk_error) {
        var copy = c
        if copy.status == BSK_OK {
            copy.status = status
        }
        self.init(copy)
    }

    public var isFailure: Bool { status != .ok }

    public var description: String {
        var parts = ["\(status)"]
        if let sipStatus {
            parts.append("SIP \(sipStatus) \(sipReason)")
        }
        if !message.isEmpty {
            parts.append(message)
        }
        return parts.joined(separator: ": ")
    }
}
