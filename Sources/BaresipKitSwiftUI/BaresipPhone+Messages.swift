import Foundation
import BaresipKit
import BaresipKitSystemCall

extension BaresipPhoneCall {
    /// Whether a SIP address names the other side of this call, such as the sender of a SIP
    /// MESSAGE; see ``samePeer(_:_:)``.
    ///
    /// - Parameter address: A SIP URI, a `From`-style address with a display name, or a user name.
    /// - Returns: `true` when the address names the call's other side.
    public func isPeer(_ address: String) -> Bool {
        Self.samePeer(address, remoteURI)
    }

    /// Whether two SIP addresses name the same party: the same user, compared without regard to
    /// case, and the same host when both name one. Display names, the scheme, the port, URI
    /// parameters and headers are ignored, so `"Door" <sip:door1@pbx:5061;transport=tls>`
    /// and `sip:door1@pbx` are the same party, and so are `door1` and `sip:door1@pbx`.
    ///
    /// - Parameters:
    ///   - first: A SIP address.
    ///   - second: Another SIP address.
    /// - Returns: `true` when both name the same user, and the same host where both name one.
    public nonisolated static func samePeer(_ first: String, _ second: String) -> Bool {
        let one = SIPIdentity(first)
        let other = SIPIdentity(second)
        guard !one.user.isEmpty, one.user == other.user else { return false }
        return one.host.isEmpty || other.host.isEmpty || one.host == other.host
    }
}

extension BaresipPhone {
    /// The established call whose other side has a SIP address, for example to show a SIP
    /// MESSAGE from that side on the call's screen.
    ///
    /// The ``activeCall`` comes first; otherwise the first established call (connected or on
    /// hold) with that side. Calls that ring or have ended do not count.
    ///
    /// - Parameter address: The sender of a message, or another SIP address.
    /// - Returns: The call, or `nil` when no established call is with that side.
    public func call(withPeer address: String) -> BaresipPhoneCall? {
        let established = calls.filter { $0.isConnected || $0.isOnHold || $0.isHeldByRemote }
        if let active = activeCall, established.contains(where: { $0 === active }), active.isPeer(address) {
            return active
        }
        return established.first { $0.isPeer(address) }
    }
}
