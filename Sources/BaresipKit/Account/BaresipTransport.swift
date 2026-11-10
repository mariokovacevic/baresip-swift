/// The SIP transport used for registration and calls.
public enum BaresipTransport: Int, Sendable, Codable {
    /// SIP over UDP.
    case udp = 0
    /// SIP over TCP.
    case tcp = 1
    /// SIP over TLS. This is the default and the recommended transport.
    case tls = 2
    /// SIP over secure WebSocket.
    case wss = 3
}
