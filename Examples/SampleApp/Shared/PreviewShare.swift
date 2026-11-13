import Foundation

/// What the app and its notification extension agree on to preview a ringing call.
enum PreviewShare {
    /// The notification category of a ringing call with a picture.
    static let category = "BSK_INCOMING_PREVIEW"
    /// The same category with the action that opens the door.
    static let doorCategory = "BSK_INCOMING_PREVIEW_DOOR"
    static let answerAction = "BSK_ANSWER"
    static let declineAction = "BSK_DECLINE"
    static let openDoorAction = "BSK_OPEN_DOOR"
    /// The key of the call's identifier in a notification's `userInfo`.
    static let callKey = "bsk-call"
    /// How often the extension looks for a newer picture, in seconds.
    static let refreshInterval: TimeInterval = 0.25

    /// The app group of the app and the extension, from the `BSKAppGroup` Info.plist entry.
    static var appGroup: String? {
        Bundle.main.object(forInfoDictionaryKey: "BSKAppGroup") as? String
    }

    /// The file with the latest picture of a call.
    ///
    /// It is in the app group's container when the build has one, so the extension reads what
    /// the app writes. Without one it is in the caches of whoever asks, where only the app
    /// finds it and the extension keeps showing the notification's own picture.
    static func pictureURL(call: String) -> URL? {
        let manager = FileManager.default
        let shared = appGroup.flatMap { manager.containerURL(forSecurityApplicationGroupIdentifier: $0) }
        guard let base = shared ?? manager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directory = base.appendingPathComponent("CallPreview", isDirectory: true)
        try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("\(call).jpg")
    }
}
