import Foundation

/// What the system call screen plays when a call rings: the iPhone's own ringtone, or one of the
/// app's sounds (`Tools/Sounds/ringtones.py` makes them).
enum Ringtone: String, CaseIterable, Identifiable {
    case iPhone = "system"
    case chime = "Chime.wav"
    case bells = "Bells.wav"
    case classic = "Classic.wav"

    /// An app sound, as a door chime is expected from an intercom.
    static let `default` = Ringtone.chime

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .iPhone: "iPhone ringtone"
        case .chime: "Chime"
        case .bells: "Bells"
        case .classic: "Classic"
        }
    }

    /// The sound file in the app bundle for the call screen, or `nil` for the iPhone's ringtone.
    var soundFile: String? {
        self == .iPhone ? nil : rawValue
    }

    var url: URL? {
        soundFile.flatMap { Bundle.main.url(forResource: $0, withExtension: nil) }
    }
}
