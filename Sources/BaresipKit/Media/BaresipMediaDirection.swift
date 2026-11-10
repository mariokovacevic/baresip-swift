/// The direction of an audio or video stream.
public enum BaresipMediaDirection: Int, Sendable, Codable {
    /// Nothing is sent or received.
    case inactive = 0
    /// Media is sent only.
    case sendOnly = 1
    /// Media is received only.
    case receiveOnly = 2
    /// Media is sent and received.
    case sendReceive = 3
}
