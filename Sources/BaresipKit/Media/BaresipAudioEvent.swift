/// The state of audio input and output.
public struct BaresipAudioEvent: Sendable, Equatable {
    /// Whether the microphone is capturing.
    public let inputRunning: Bool
    /// Whether the speaker or receiver is playing.
    public let outputRunning: Bool
    /// The error that stopped audio, if any.
    public let error: BaresipError?
}
