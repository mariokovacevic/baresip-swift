/// The part of the engine a log entry comes from.
public enum BaresipLogDomain: Int, Sendable, Codable {
    /// Engine lifecycle, configuration and the facade itself.
    case core = 0
    /// SIP signalling, including SIP traces when enabled.
    case sip = 1
    /// Audio, video, RTP and ICE.
    case media = 2
}
