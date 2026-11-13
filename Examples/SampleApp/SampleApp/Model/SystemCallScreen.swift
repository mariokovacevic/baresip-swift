import Foundation

/// The system framework that shows calls on the iPhone's call screen. Both give the same calls;
/// LiveCommunicationKit is CallKit's successor and needs iOS 17.4.
enum SystemCallScreen: String, CaseIterable, Identifiable {
    case callKit
    case liveCommunicationKit

    static let `default` = SystemCallScreen.callKit

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .callKit: "CallKit"
        case .liveCommunicationKit: "LiveCommunicationKit"
        }
    }

    var detail: String {
        switch self {
        case .callKit: "The call screen apps have used since iOS 10"
        case .liveCommunicationKit: "CallKit's successor, from iOS 17.4"
        }
    }

    /// Whether this iPhone runs a version of iOS that has the framework.
    var isAvailable: Bool {
        switch self {
        case .callKit:
            return true
        case .liveCommunicationKit:
            if #available(iOS 17.4, *) {
                return true
            }
            return false
        }
    }

    /// The framework used: LiveCommunicationKit falls back to CallKit before iOS 17.4.
    var effective: SystemCallScreen {
        isAvailable ? self : .callKit
    }
}
