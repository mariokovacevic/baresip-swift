import Foundation

/// Settings for the CallKit provider created by ``BaresipCallKitAdapter``.
public struct BaresipCallKitConfiguration: Sendable {
    /// Whether calls may have video.
    public var supportsVideo: Bool
    /// The number of calls CallKit allows in one call group.
    public var maximumCallsPerCallGroup: Int
    /// A template image (PNG data) shown on the system call screen.
    public var iconTemplateImageData: Data?
    /// The name of a sound file in the app bundle used as the ringtone.
    public var ringtoneSound: String?
    /// How long a call reported from a VoIP push waits for its INVITE before it is ended.
    public var pushInviteTimeout: Duration = .seconds(30)
    /// Whether answering a video call from the system call screen sends your camera. With
    /// `false` the caller's video is still received; turn the camera on later with
    /// `BaresipEngine.setVideoEnabled(_:callID:)`. `true` by default.
    public var sendsCameraOnAnswer = true
    /// Whether a call reported from a VoIP push that names no caller is bound to the next INVITE,
    /// whoever sends it. `true` by default.
    ///
    /// With `false`, a push without a caller is never bound to an INVITE: the pushed call ends
    /// after ``pushInviteTimeout`` and the INVITE is reported as a call of its own. Use `false`
    /// when every push carries the caller's SIP URI.
    public var matchesPushWithoutCaller = true

    /// Creates CallKit settings.
    ///
    /// - Parameters:
    ///   - supportsVideo: Whether calls may have video.
    ///   - maximumCallsPerCallGroup: The number of calls per call group.
    ///   - iconTemplateImageData: The call screen icon.
    ///   - ringtoneSound: The ringtone file name.
    public init(supportsVideo: Bool = true, maximumCallsPerCallGroup: Int = 1,
                iconTemplateImageData: Data? = nil, ringtoneSound: String? = nil) {
        self.supportsVideo = supportsVideo
        self.maximumCallsPerCallGroup = maximumCallsPerCallGroup
        self.iconTemplateImageData = iconTemplateImageData
        self.ringtoneSound = ringtoneSound
    }
}
