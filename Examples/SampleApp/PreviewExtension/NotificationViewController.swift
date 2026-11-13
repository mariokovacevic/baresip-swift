import UIKit
import UserNotifications
import UserNotificationsUI

/// Shows the picture of a ringing call in its expanded notification and replaces it with the
/// pictures the app keeps saving while the call rings.
final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private static let liveWindow: TimeInterval = 2
    private static let margin: CGFloat = 8

    private let imageView = UIImageView()
    private let statusLabel = UILabel()
    private var timer: Timer?
    private var picture: URL?
    private var lastModified: Date?
    private var lastChange = Date.distantPast

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .preferredFont(forTextStyle: .caption1)
        statusLabel.textColor = .white
        statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        statusLabel.isHidden = true
        view.addSubview(imageView)
        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Self.margin),
            statusLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -Self.margin),
        ])
    }

    func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        showAttachment(of: content)
        timer?.invalidate()
        timer = nil
        guard let call = content.userInfo[PreviewShare.callKey] as? String else { return }
        picture = PreviewShare.pictureURL(call: call)
        refresh()
        timer = Timer.scheduledTimer(timeInterval: PreviewShare.refreshInterval, target: self,
                                     selector: #selector(refresh), userInfo: nil, repeats: true)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        timer?.invalidate()
        timer = nil
    }

    private func showAttachment(of content: UNNotificationContent) {
        guard let url = content.attachments.first?.url, url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            imageView.image = image
        }
    }

    @objc private func refresh() {
        if let picture, let modified = modificationDate(of: picture), modified != lastModified,
           let data = try? Data(contentsOf: picture), let image = UIImage(data: data) {
            lastModified = modified
            lastChange = Date()
            imageView.image = image
        }
        let live = Date().timeIntervalSince(lastChange) < Self.liveWindow
        statusLabel.text = live ? "  LIVE  " : "  Picture from when it rang  "
        statusLabel.isHidden = imageView.image == nil
    }

    private func modificationDate(of url: URL) -> Date? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attributes?[.modificationDate] as? Date
    }
}
