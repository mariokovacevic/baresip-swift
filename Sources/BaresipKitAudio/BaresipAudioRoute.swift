import Foundation

/// Where call audio is played.
public enum BaresipAudioRoute: Sendable, Hashable {
    /// The receiver at the top of the phone.
    case earpiece
    /// The built-in loudspeaker.
    case speaker
    /// A Bluetooth headset or car kit.
    case bluetooth
    /// Wired or USB headphones.
    case wiredHeadset
    /// Another output, with its AVFoundation port type.
    case other(String)
}
