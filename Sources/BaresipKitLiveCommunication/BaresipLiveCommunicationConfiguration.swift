import Foundation
import BaresipKit

/// An error of `BaresipLiveCommunicationAdapter` that comes neither from LiveCommunicationKit nor
/// from the engine.
public enum BaresipLiveCommunicationError: Error, Sendable, Equatable {
    /// The adapter knows no call for the conversation or the engine call.
    case unknownCall
    /// The system asked for an action the adapter does not carry out, such as merging calls.
    case unsupportedAction
    /// LiveCommunicationKit gave up on an action because the adapter did not finish it in time,
    /// or the system did not carry out a requested action within a minute.
    case actionTimedOut
    /// The system reset the conversation manager while the action was pending; every call was
    /// ended.
    case managerReset
}

/// Settings for the conversation manager created by `BaresipLiveCommunicationAdapter`.
public struct BaresipLiveCommunicationConfiguration: Sendable {
    /// Whether calls may have video.
    public var supportsVideo: Bool
    /// The number of conversation groups the system allows at once.
    public var maximumConversationGroups: Int
    /// The number of calls the system allows in one conversation group.
    public var maximumConversationsPerConversationGroup: Int
    /// A template image (PNG data) shown on the system call screen.
    public var iconTemplateImageData: Data?
    /// The name of a sound file in the app bundle used as the ringtone, or `nil` for the
    /// ringtone chosen in the iOS Settings app. LiveCommunicationKit fixes it when the adapter is
    /// created; create a new adapter to change it.
    public var ringtoneName: String?
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
    /// after ``pushInviteTimeout`` and the INVITE is reported as a call of its own.
    public var matchesPushWithoutCaller = true
    /// The name of an INVITE header that carries the UUID of the call, the one the server also
    /// puts in the VoIP push. `nil` by default.
    ///
    /// With a header name, a call reported from a push is bound to the INVITE with the same UUID
    /// and to no other, whoever the caller is. An INVITE without the header is matched by its
    /// caller.
    public var callUUIDHeader: String?
    /// Whether calls appear in the Recents list of the Phone app. `true` by default.
    ///
    /// A tap on such an entry asks the app to call again; see `BaresipRedialRequest`.
    public var includesCallsInRecents = true
    /// How callers are identified to the system. `BaresipHandleStyle.sipURI` by default.
    public var handleStyle: BaresipHandleStyle = .sipURI

    /// Creates LiveCommunicationKit settings.
    ///
    /// - Parameters:
    ///   - supportsVideo: Whether calls may have video.
    ///   - maximumConversationGroups: The number of conversation groups.
    ///   - maximumConversationsPerConversationGroup: The number of calls per conversation group.
    ///   - iconTemplateImageData: The call screen icon.
    ///   - ringtoneName: The ringtone file name.
    public init(supportsVideo: Bool = true, maximumConversationGroups: Int = 1,
                maximumConversationsPerConversationGroup: Int = 1, iconTemplateImageData: Data? = nil,
                ringtoneName: String? = nil) {
        self.supportsVideo = supportsVideo
        self.maximumConversationGroups = maximumConversationGroups
        self.maximumConversationsPerConversationGroup = maximumConversationsPerConversationGroup
        self.iconTemplateImageData = iconTemplateImageData
        self.ringtoneName = ringtoneName
    }
}
