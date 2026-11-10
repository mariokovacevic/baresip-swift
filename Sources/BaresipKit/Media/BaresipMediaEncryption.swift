/// How call media is encrypted.
public enum BaresipMediaEncryption: Int, Sendable, Codable {
    /// Plain RTP.
    case none = 0
    /// SDES-SRTP when the peer offers or accepts it, plain RTP otherwise.
    case srtpOptional = 1
    /// SDES-SRTP only; calls without it fail.
    case srtpMandatory = 2
    /// DTLS-SRTP.
    case dtlsSRTP = 3
}
