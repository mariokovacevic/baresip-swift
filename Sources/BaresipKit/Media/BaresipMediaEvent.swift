/// A change in a call's media.
///
/// New cases can be added in a minor release; end a `switch` over it with `default:`. See
/// [Stability](https://github.com/mariokovacevic/baresipkit/blob/main/Docs/STABILITY.md).
public enum BaresipMediaEvent: Int, Sendable, Codable {
    /// The core reported an event this version of BaresipKit does not know.
    case unknown = -1
    /// The audio stream started.
    case audioStarted = 0
    /// The remote side put the call on hold.
    case remoteHold = 4
    /// The remote side resumed the call.
    case remoteResume = 5
    /// Media encryption was established.
    case encryptionEstablished = 6
    /// The remote side asked for a video keyframe.
    case keyframeRequested = 8
    /// The caller offers video during early media.
    case earlyVideoAvailable = 9
    /// Recording started; see ``BaresipEngine/startRecording(callID:to:)``.
    case recordingStarted = 10
    /// Recording stopped and the file is complete.
    case recordingStopped = 11
}
