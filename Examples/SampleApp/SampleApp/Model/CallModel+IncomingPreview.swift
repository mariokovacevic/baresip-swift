import UIKit
import BaresipKit
import BaresipKitSwiftUI

/// The picture of a ringing call: saved a few times a second while the call rings, shown in a
/// notification with Answer and Decline while the app is in the background, and left in a
/// notification when the call was missed.
extension CallModel {
    var backgroundBehavior: BaresipAppLifecycle.BackgroundBehavior {
        settings.reachableInBackground ? .suspend : .goOffline
    }

    /// The saved door a ringing call comes from, when its notification may open it.
    private func notificationDoor(_ call: BaresipCallID) -> Door? {
        door(of: phone?.call(call)).flatMap { $0.canOpen && $0.opensFromNotification ? $0 : nil }
    }

    private static func notificationID(_ call: BaresipCallID) -> String {
        "\(call.rawValue)"
    }

    /// Sends the ringing call's video through a feed that saves pictures of it.
    func startPreviewFeed(_ call: BaresipCallID) async {
        guard let engine, previewFeed?.call != call,
              let file = PreviewShare.pictureURL(call: Self.notificationID(call)) else { return }
        previewFeed?.stop()
        previewPictureReady = false
        let feed = CallPreviewFeed(call: call, file: file) { [weak self] in
            Task { @MainActor [weak self] in
                self?.previewPictureSaved(call)
            }
        }
        previewFeed = feed
        do {
            try await engine.setVideoRenderer(feed, callID: call)
        } catch {
            previewFeed = nil
            append("preview pictures unavailable: \(error)")
        }
    }

    private func previewPictureSaved(_ call: BaresipCallID) {
        guard previewFeed?.call == call else { return }
        previewPictureReady = true
        showPreviewNotificationIfHidden()
    }

    /// Shows the notification when a call rings with a picture while the app is in the background.
    func showPreviewNotificationIfHidden() {
        guard settings.ringPicture, let feed = previewFeed, previewPictureReady, previewNotified != feed.call,
              ringingCalls.contains(feed.call), UIApplication.shared.applicationState == .background else { return }
        previewNotified = feed.call
        let title = phone?.call(feed.call)?.displayName ?? ""
        PreviewNotifications.show(ring(feed, title: title), onFailure: notificationFailed)
        append("preview notification shown for \(feed.call)")
    }

    /// Stops saving pictures of a call that was answered, declined or ended.
    ///
    /// - Parameters:
    ///   - call: The call.
    ///   - name: The caller's name when the call ended unanswered, to leave a notification with
    ///     the last picture; `nil` otherwise.
    func endPreviewFeed(_ call: BaresipCallID, missedCallFrom name: String?) {
        guard let feed = previewFeed, feed.call == call else { return }
        if let name, settings.ringPicture, previewPictureReady, UIApplication.shared.applicationState != .active {
            PreviewNotifications.showMissed(ring(feed, title: name), onFailure: notificationFailed)
        } else if previewNotified == call {
            PreviewNotifications.remove(call: Self.notificationID(call))
        }
        feed.stop()
        previewFeed = nil
        previewNotified = nil
        previewPictureReady = false
    }

    /// Answers, declines or opens the door for the call of a notification. A tap on the
    /// notification itself only opens the app, which shows the incoming call.
    func previewNotificationAction(_ action: String, call: String?) async {
        guard let call, let target = phone?.calls.first(where: { Self.notificationID($0.id) == call }),
              target.isRinging else { return }
        if incoming?.id != target.id {
            shownIncoming = target.id
        }
        switch action {
        case PreviewShare.answerAction: await answer()
        case PreviewShare.declineAction: await reject()
        case PreviewShare.openDoorAction:
            if let door = notificationDoor(target.id) {
                await openDoor(target, with: door)
            }
        default: break
        }
    }

    private func ring(_ feed: CallPreviewFeed, title: String) -> PreviewNotifications.Ring {
        let door = notificationDoor(feed.call)
        let name = door?.title ?? (title.isEmpty ? "Incoming call" : title)
        return PreviewNotifications.Ring(call: Self.notificationID(feed.call), title: name, picture: feed.file,
                                         opensDoor: door != nil)
    }

    var notificationFailed: @Sendable (String) -> Void {
        { [weak self] message in
            Task { @MainActor [weak self] in
                self?.append("preview notification failed: \(message)")
            }
        }
    }
}
