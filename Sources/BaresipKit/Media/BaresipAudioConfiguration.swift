import Foundation

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
    /// The RTP packet time offered to the peer.
    public var packetTime: Duration
    /// The jitter buffer range in milliseconds.
    public var jitterBufferRange: ClosedRange<Int>
    /// Whether the jitter buffer adapts within ``jitterBufferRange``.
    public var adaptiveJitterBuffer: Bool
    /// Audio codecs in order of preference, as `name/rate/channels`.
    public var codecs: [String]
    /// Music on hold: a WAV file (16-bit PCM, mono or stereo, 8 to 48 kHz) that a call put on
    /// hold with ``BaresipEngine/hold(callID:)`` plays to the other side in a loop instead of
    /// the microphone, like liblinphone's play file. It plays without the audio session, so
    /// also while iOS has deactivated it for a held call. `nil` sends nothing while on hold.
    ///
    /// The engine reads the file when it is created and fails with ``BaresipError`` when the
    /// file is missing or in another format.
    public var holdMusicFile: URL?

    /// The codecs offered when an account configures none: Opus, G.722, then G.711 µ-law and
    /// A-law. G.722 is written with its audio rate, `G722/16000/1`.
    public static let defaultCodecs = ["opus/48000/2", "G722/16000/1", "PCMU/8000/1", "PCMA/8000/1"]

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
    ///   - codecs: Codecs in order of preference.
    ///   - holdMusicFile: The WAV file a held call plays to the other side.
    public init(sourceModule: String = "audiounit", sourceDevice: String? = nil,
                playerModule: String = "audiounit", playerDevice: String? = nil,
                sampleRate: Int? = nil, channels: Int? = nil,
                packetTime: Duration = .milliseconds(20),
                jitterBufferRange: ClosedRange<Int> = 40 ... 200,
                adaptiveJitterBuffer: Bool = true,
                codecs: [String] = BaresipAudioConfiguration.defaultCodecs,
                holdMusicFile: URL? = nil) {
        self.sourceModule = sourceModule
        self.sourceDevice = sourceDevice
        self.playerModule = playerModule
        self.playerDevice = playerDevice
        self.sampleRate = sampleRate
        self.channels = channels
        self.packetTime = packetTime
        self.jitterBufferRange = jitterBufferRange
        self.adaptiveJitterBuffer = adaptiveJitterBuffer
        self.codecs = codecs
        self.holdMusicFile = holdMusicFile
    }
}
