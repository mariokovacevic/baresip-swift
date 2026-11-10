import Foundation

/// DTMF sent on a call, as a door station expects: the digits, the digit the station replies
/// with when it accepted them (empty when no reply is expected), and whether to hang up after.
struct DTMFRequest: Equatable {
    var digits: String
    var ack: String
    var hangUp: Bool

    static let ackTimeout: Duration = .seconds(10)
    static let hangUpDelay: Duration = .seconds(1)
}
