import UIKit
import UserNotifications

/// Registers for regular push notifications, whose APNs token the server receives next to the
/// VoIP token (`pn-tok=<remote>:remote&<voip>:voip`), and shows them while the app is open.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    @MainActor weak var model: CallModel? {
        didSet {
            if let remoteToken {
                model?.remoteTokenArrived(remoteToken)
            }
        }
    }

    @MainActor private var remoteToken: Data?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil)
        -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        remoteToken = deviceToken
        model?.remoteTokenArrived(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        model?.append("push notifications unavailable: \(error.localizedDescription)")
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification)
        async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    /// Passes a tap on a ringing call's notification, or on one of its actions, to the model.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let action = response.actionIdentifier
        let call = response.notification.request.content.userInfo[PreviewShare.callKey] as? String
        await previewAction(action, call: call)
    }

    private func previewAction(_ action: String, call: String?) async {
        await model?.previewNotificationAction(action, call: call)
    }
}
