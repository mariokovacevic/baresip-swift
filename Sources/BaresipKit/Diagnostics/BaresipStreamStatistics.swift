/// RTP statistics for one stream of a call.
public struct BaresipStreamStatistics: Sendable, Equatable {
    /// RTP packets sent.
    public let transmittedPackets: UInt32
    /// RTP packets received.
    public let receivedPackets: UInt32
    /// RTP payload bytes sent.
    public let transmittedBytes: UInt64
    /// RTP payload bytes received.
    public let receivedBytes: UInt64
    /// The cumulative number of packets lost in the received stream.
    public let receivedLost: Int32
    /// The fraction of received packets lost, in tenths of a percent.
    public let receivedFractionLostPermille: UInt32
    /// The interarrival jitter of the received stream.
    public let receivedJitter: Duration
    /// The round-trip time from RTCP.
    public let roundTripTime: Duration
    /// The sending bitrate in bits per second.
    public let transmitBitrate: UInt32
    /// The receiving bitrate in bits per second.
    public let receiveBitrate: UInt32
    /// The current jitter buffer delay.
    public let jitterBufferDelay: Duration
    /// Whether the stream is encrypted.
    public let isSecure: Bool
}
