import Foundation

/// Settings for the CallKit provider created by ``BaresipCallKitAdapter``.
public struct BaresipCallKitConfiguration: Sendable {
    /// Has no effect: current SDKs show the app name from the Info.plist.
    @available(*, deprecated, message: "CXProviderConfiguration.localizedName is read-only in current SDKs; CallKit shows the app name from the Info.plist.")
    public var localizedName: String = ""
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

    /// Creates CallKit settings with a localized name, which has no effect.
    @available(*, deprecated, message: "localizedName has no effect; use init(supportsVideo:maximumCallsPerCallGroup:iconTemplateImageData:ringtoneSound:)")
    public init(localizedName: String, supportsVideo: Bool = true, maximumCallsPerCallGroup: Int = 1,
                iconTemplateImageData: Data? = nil, ringtoneSound: String? = nil) {
        self.init(supportsVideo: supportsVideo, maximumCallsPerCallGroup: maximumCallsPerCallGroup,
                  iconTemplateImageData: iconTemplateImageData, ringtoneSound: ringtoneSound)
        self.localizedName = localizedName
    }
}
