import Foundation

/// An output the user can choose for call audio.
public struct BaresipAudioOutput: Identifiable, Hashable, Sendable {
    /// A stable identifier: the port UID, or a fixed value for the earpiece and loudspeaker.
    public let id: String
    /// A name to show, such as "Speaker" or the Bluetooth device's name.
    public let name: String
    /// The kind of output.
    public let route: BaresipAudioRoute

    /// The receiver at the top of the phone.
    public static let earpiece = BaresipAudioOutput(id: "bsk.earpiece", name: "iPhone", route: .earpiece)
    /// The built-in loudspeaker.
    public static let speaker = BaresipAudioOutput(id: "bsk.speaker", name: "Speaker", route: .speaker)
}
