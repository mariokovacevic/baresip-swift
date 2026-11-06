/// Audio settings for the engine.
public struct BaresipAudioConfiguration: Sendable, Equatable {
    /// The baresip audio source module, `audiounit` on iOS.
    public var sourceModule: String
    /// The input device, or `nil` for the default.
    public var sourceDevice: String?
    /// The baresip audio player module, `audiounit` on iOS.
    public var playerModule: String
    /// The output device, or `nil` for the default.
    public var playerDevice: String?
    /// The capture and playback sample rate, or `nil` to follow the codec.
    public var sampleRate: Int?
    /// The number of channels, or `nil` to follow the codec.
    public var channels: Int?
    /// The RTP packet time.
    public var packetTime: Duration
    /// The jitter buffer range in milliseconds.
    public var jitterBufferRange: ClosedRange<Int>
    /// Whether the jitter buffer adapts within ``jitterBufferRange``.
    public var adaptiveJitterBuffer: Bool
    /// Whether the iOS voice processing unit (echo cancellation, gain control) is used.
    public var voiceProcessing: Bool
    /// Audio codecs in order of preference, as `name/rate/channels`.
    public var codecs: [String]

    /// The codecs offered when none are configured: Opus, then G.711 µ-law and A-law.
    public static let defaultCodecs = ["opus/48000/2", "PCMU/8000/1", "PCMA/8000/1"]

    /// Creates audio settings.
    ///
    /// - Parameters:
    ///   - sourceModule: The audio source module.
    ///   - sourceDevice: The input device.
    ///   - playerModule: The audio player module.
    ///   - playerDevice: The output device.
    ///   - sampleRate: The sample rate.
    ///   - channels: The number of channels.
    ///   - packetTime: The RTP packet time.
    ///   - jitterBufferRange: The jitter buffer range in milliseconds.
    ///   - adaptiveJitterBuffer: Whether the jitter buffer adapts.
    ///   - voiceProcessing: Whether voice processing is on.
    ///   - codecs: Codecs in order of preference.
    public init(sourceModule: String = "audiounit", sourceDevice: String? = nil,
                playerModule: String = "audiounit", playerDevice: String? = nil,
                sampleRate: Int? = nil, channels: Int? = nil,
                packetTime: Duration = .milliseconds(20),
                jitterBufferRange: ClosedRange<Int> = 40 ... 200,
                adaptiveJitterBuffer: Bool = true, voiceProcessing: Bool = true,
                codecs: [String] = BaresipAudioConfiguration.defaultCodecs) {
        self.sourceModule = sourceModule
        self.sourceDevice = sourceDevice
        self.playerModule = playerModule
        self.playerDevice = playerDevice
        self.sampleRate = sampleRate
        self.channels = channels
        self.packetTime = packetTime
        self.jitterBufferRange = jitterBufferRange
        self.adaptiveJitterBuffer = adaptiveJitterBuffer
        self.voiceProcessing = voiceProcessing
        self.codecs = codecs
    }
}
