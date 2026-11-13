import Foundation
import UserNotifications

/// The notification that shows a ringing call's picture while the app is in the background,
/// and the one left behind when the call was missed.
@MainActor
enum PreviewNotifications {
    struct Ring {
        let call: String
        let title: String
        let picture: URL
        let opensDoor: Bool
    }

    /// Registers the notification categories with Answer, Decline and Open door.
    static func registerCategories() {
        let answer = UNNotificationAction(identifier: PreviewShare.answerAction, title: "Answer",
                                          options: [.foreground])
        let decline = UNNotificationAction(identifier: PreviewShare.declineAction, title: "Decline",
                                           options: [.destructive])
        let door = UNNotificationAction(identifier: PreviewShare.openDoorAction, title: "Open door",
                                        options: [.authenticationRequired])
        let plain = UNNotificationCategory(identifier: PreviewShare.category, actions: [answer, decline],
                                           intentIdentifiers: [], options: [])
        let withDoor = UNNotificationCategory(identifier: PreviewShare.doorCategory,
                                              actions: [answer, door, decline], intentIdentifiers: [],
                                              options: [])
        UNUserNotificationCenter.current().setNotificationCategories([plain, withDoor])
    }

    /// Shows the ringing call with its picture; the expanded notification shows newer pictures.
    static func show(_ ring: Ring, onFailure: @escaping @Sendable (String) -> Void) {
        let content = UNMutableNotificationContent()
        content.title = ring.title
        content.body = "Ringing. Touch and hold to watch, tap to open."
        content.categoryIdentifier = ring.opensDoor ? PreviewShare.doorCategory : PreviewShare.category
        content.userInfo = [PreviewShare.callKey: ring.call]
        content.interruptionLevel = .timeSensitive
        content.attachments = attachments(copying: ring.picture)
        add(content, call: ring.call, onFailure: onFailure)
    }

    /// Replaces the ringing call's notification with one that keeps its last picture.
    static func showMissed(_ ring: Ring, onFailure: @escaping @Sendable (String) -> Void) {
        let content = UNMutableNotificationContent()
        content.title = ring.title
        content.body = "Missed ring"
        content.attachments = attachments(copying: ring.picture)
        add(content, call: ring.call, onFailure: onFailure)
    }

    /// Shows a received message while the app is in the background.
    static func showMessage(from sender: String, text: String, onFailure: @escaping @Sendable (String) -> Void) {
        let content = UNMutableNotificationContent()
        content.title = sender
        content.body = text
        content.sound = .default
        add(content, call: "message-\(UUID().uuidString)", onFailure: onFailure)
    }

    static func remove(call: String) {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier(call)])
    }

    private static func identifier(_ call: String) -> String {
        "bsk-preview-\(call)"
    }

    private static func add(_ content: UNNotificationContent, call: String,
                            onFailure: @escaping @Sendable (String) -> Void) {
        let request = UNNotificationRequest(identifier: identifier(call), content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                onFailure(error.localizedDescription)
            }
        }
    }

    /// The system moves an attachment's file away, so it gets a copy of the picture.
    private static func attachments(copying picture: URL) -> [UNNotificationAttachment] {
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
        guard (try? FileManager.default.copyItem(at: picture, to: copy)) != nil,
              let attachment = try? UNNotificationAttachment(identifier: "picture", url: copy, options: nil)
        else { return [] }
        return [attachment]
    }
}
