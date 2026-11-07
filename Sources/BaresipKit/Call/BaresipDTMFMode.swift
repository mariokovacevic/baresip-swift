/// How DTMF digits are sent during a call.
public enum BaresipDTMFMode: Int, Sendable, Codable {
    /// RTP telephone events (RFC 4733) when the peer supports them, SIP INFO otherwise.
    case auto = 0
    /// RTP telephone events only.
    case rtpEvent = 1
    /// SIP INFO requests only.
    case sipInfo = 2
}
